require 'rmagick' unless Rails.env.development?
require 'open-uri'
require 'mechanize'
require 'fileutils'
require 'array_utils'

class ImageReference < ApplicationRecord

  include Referrable # Can be linked to a Referent

  include Backgroundable

  backgroundable :status

  # attr_accessible :type, :url, :filename, :link_text

  validates_uniqueness_of :url

  # An ImageReference maintains a local thumbnail of the image for all these entities
  has_many :feeds, :foreign_key => :picture_id, :dependent => :nullify
  has_many :feed_entries, :foreign_key => :picture_id, :dependent => :nullify
  has_many :lists, :foreign_key => :picture_id, :dependent => :nullify
  has_many :products, :foreign_key => :picture_id, :dependent => :nullify
  has_many :recipes, :foreign_key => :picture_id, :dependent => :nullify
  has_many :page_refs, :foreign_key => :picture_id, :dependent => :nullify
  has_many :referents, :foreign_key => :picture_id, :dependent => :nullify
  has_many :sites, :foreign_key => :thumbnail_id, :dependent => :nullify
  has_many :users, :foreign_key => :thumbnail_id, :dependent => :nullify
  has_many :referments, :as => :referee, :dependent => :destroy
  # has_many :referents, :through => :referments

  public

  # By default, the reference gives up its url, but may want to use something else, like image data
  def digested_reference
    url
  end

  # Provide a relation for entities that match a string
  def self.strscopes matcher
    [
        (block_given? ? yield() : self).where('"references"."host" ILIKE ?', matcher)
    ]
  end

  # Get data from the reference via HTTP
  def fetch starter=nil
    def get_response url
      self.errcode = response = nil
      begin
        uri = URI.parse url
        if uri.host &&
            uri.port &&
            (http = Net::HTTP.new(uri.host, uri.port)) &&
            (uri.scheme != 'https' || (http.use_ssl = true && http.verify_mode = OpenSSL::SSL::VERIFY_NONE)) # read into this
            (request = Net::HTTP::Get.new(uri.request_uri, 'upgrade-insecure-requests' => '1'))
          response = http.request request
          self.errcode = response.code.to_i
        else # Invalid URL
          self.errcode = 400
        end
      rescue Exception => e
        # If the server doesn't want to talk, we assume that the URL is okay, at least
        case e
          when Errno::ECONNRESET
            self.errcode = 401
          else
            self.errcode = -1  # Undifferentiated error during fetch, possibly a parsing problem
        end
      end
      response
    end

    # get_response records the errcode of the last HTTP access in self.errcode
    tried = {}
    next_try = starter || url
    until tried[next_try]
      tried[next_try] = true
      response = get_response next_try
      case errcode
        when 200
          return response.body
        when 301, 302 # Redirection
          next_try = response.header['location']
        when 401 # Unauthorized
          next_try.sub! /^https/, 'http'
      end
    end
    # Failure to access the image
    err_msg = "Error #{errcode} reading image at #{url} on ImageReference ##{id}"
    errors.add :url, 'doesn\'t work: ' + err_msg
    raise err_msg unless errcode == 404
  end

  def relaunch?
    errors.present? && (errcode != 404)
  end

  # Index an ImageReference by URL or URLs, assuming it exists (i.e., no initialization or creation)
  def self.lookup url
    begin
      url = normalize_url url
    rescue
      # If we can't normalize the url, then use the un-normalized version and hope for the best
      return self.where( '"references"."url" ILIKE ?', "#{url}%" )
    end
    url.sub! /^https?:\/\//, ''  # Elide the protocol, if any
    self.find_by url: [ 'http://'+url, 'https://'+url ]
  end

  # Since the URL is never written once established, this method uniquely handles both
  # data URLs (for images with data only and no URL) and fake URLS (which are left in place for the latter)
  # NB: Implicit in here is the strategy for maintainng the data: since we only fetch reference
  # records by URL when assigning a URL to an entity, we only go off to update the data when
  # the URL is assigned
  def self.find_or_initialize url
    case url
    when /^\d\d\d\d-/
      self.find_by url: url # Fake url previously defined
    when /^data:/
      # Data URL for imagery is acceptable, but it's stored in #thumbdata, with a fake but unique nonsense URL
      self.find_by(thumbdata: url) ||
          begin
            ref = self.new(url: self.fake_url)
            ref.write_attribute :thumbdata, url
            ref.status = :good
            ref
          end
    when nil
    when ''
    else # Presumably this is a valid URL
      # Normalize for lookup
      normalized = normalize_url url
      if normalized.blank? # Check for non-empty URL
        ref = self.new # Initialize a record just to report the error
        ref.errors.add :url, "can't be blank"
        ref
      elsif ref = self.lookup(normalized) # Success on the normalized URL => Success!
        ref
      elsif !(redirected = test_url normalized) # Purports to be a url, but doesn't work
        ref = self.new # Initialize a record just to report the error
        ref.errors.add :url, "\'#{url}\' doesn't seem to be a working URL. Can you use it as an address in your browser?"
        ref
      else
        ref = self.lookup(redirected) || self.new(url: redirected)
        ref
      end
    end
  end

  # Provide a url that's valid anywhere. It may come direct from the IR or, if there's only thumbdata,
  # it gets stored on AWS and returned as a link to there
  def imgurl
    if url.match /^\d\d\d\d-/
      # The more complicated case: we have an IR with image data, but no URL.
      # So we lookup the corresponding URL on AWS. If it exists, we return that;
      # Otherwise, we CREATE it on AWS first, then return it.
      #
      # Does the resource exist? If so, we just return the link
      path = "uploads/reference/#{id}.png"
      obj = S3_BUCKET.objects[path]
      unless obj.exists?
        puts 'Creating AWS file ' + path
        # The nut of the problem: take the image in the thumbdata, upload it to aws, and return the link
        b64 = thumbdata.sub 'data:image/png;base64,', ''
        img = Magick::Image.read_inline(b64).first
        S3_BUCKET.objects[path].write img.to_blob, {:acl=>:public_read}
      end
      obj.public_url.to_s
    else
      return url
    end
  end

  # Provide suitable content for an <img> element: preferably data, but possibly a url or even (if the data fetch fails) nil
  def imgdata force=false
    # Provide good thumbdata if possible
    bkg_land if force # Doesn't return until the job is done
    thumbdata.present? ? thumbdata : url
  end

  # Try to fetch thumbnail data for the record. Status code assigned in ImageReference#fetchable and ImageReference#fetch
  def perform
    logger.info ">>>>>>>>>>>>>>>>>>>>>>>>>>>>> Acquiring Thumbnail data on url '#{url}' >>>>>>>>>>>>>>>>>>>>>>>>>"
    # A url which is a date string denotes an ImageReference which came in as data, and is therefore good
    (url =~ /^\d\d\d\d-/) ||
    begin
      self.errcode = 0 if self.errcode == -2
      if response_body = fetch # Attempt to get data at the other end of the URL
        begin
          img = Magick::Image::from_blob(response_body).first
          if img.columns > 200
            scalefactor = 200.0/img.columns
            thumb = img.scale(scalefactor)
          else
            thumb = img
          end
          thumb.format = 'PNG'
          quality = 80
          self.thumbdata = 'data:image/png;base64,' + Base64.encode64(thumb.to_blob { self.quality = quality })
        rescue Exception => e
          self.errcode = -2 # Bad data
          err_msg = "couldn't parse to image data: ImageReference #{id}: #{url} (#{e})"
          errors.add :url, err_msg
          raise err_msg
        end
      end
    end
  end

  # Provide the phony (but unique) URL that's used for a data-only image
  def self.fake_url
    randstr = (0...8).map { (65 + rand(26)).chr }.join
    Time.new.to_s + randstr
  end

  # Is the reference un-gleanable? No further attention need be paid
  def definitive?
    if url =~ /^\d\d\d\d-/
      (good! && save) unless good?
      true
    elsif url.blank?
      (bad! && save) unless bad?
      true
    end
  end

  # Ensure the thumbdata is up to date, optionally forcing an update even if previously processed
  def bkg_launch force=false
    super unless definitive?
  end

  def bkg_land force=false
    super unless definitive?
  end

  def after
    self.status = (url =~ /^\d\d\d\d-/) || (errcode == 200) ? :good : :bad
    super
  end

  def thumbdata
    self[:thumbdata]
  end

  def thumbdata=(val)
    write_attribute :thumbdata, val
  end

end
