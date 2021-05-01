require 'rmagick' unless Rails.env.development?
require 'open-uri'
require 'mechanize'
require 'fileutils'
require 'array_utils'

class ImageReference < ApplicationRecord
  include Referrable # Can be linked to a Referent
  include Backgroundable
  backgroundable :status
  include Trackable
  attr_trackable :thumbdata

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
  
  def url= new_url
    super
    refresh_attributes [:thumbdata] if url_changed? && !fake_url?
  end

  # Provide a url that's valid anywhere. It may come direct from the IR or, if there's only thumbdata,
  # it gets stored on AWS and returned as a link to there
  def imgurl
    return url unless fake_url?
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
      S3_BUCKET.objects[path].write img.to_blob, {:acl => :public_read}
    end
    obj.public_url.to_s
  end

  # Provide suitable content for an <img> element: preferably data, but possibly a url or even (if the data fetch fails) nil
  def imgdata
    # If the image capture hasn't completed, return the url
    thumbdata.present? ? thumbdata : url
  end

  # Try to fetch thumbnail data for the record. Status code assigned in ImageReference#fetchable and ImageReference#fetch
  def perform
    logger.info ">>>>>>>>>>>>>>>>>>>>>>>>>>>>> Acquiring Thumbnail data on url '#{url}' >>>>>>>>>>>>>>>>>>>>>>>>>"
    # A url which is a date string denotes an ImageReference which came in as data, and is therefore good
    if fake_url?
      attrib_needed! :thumbdata, false
      return
    end
    self.errcode = 0 if errcode == -2
    if response_body = fetch # Attempt to get data at the other end of the URL
      begin
        img = Magick::Image::from_blob(response_body).first
        if img.columns > 200
          scalefactor = 200.0 / img.columns
          thumb = img.scale(scalefactor)
        else
          thumb = img
        end
        thumb.format = 'PNG'
        quality = 80
        accept_attribute :thumbdata, 'data:image/png;base64,' + Base64.encode64(thumb.to_blob { self.quality = quality })
      rescue Exception => e
        self.errcode = -2 # Bad data
        err_msg = "couldn't parse to image data: ImageReference #{id}: #{url} (#{e})"
        errors.add :url, err_msg
        raise err_msg
      end
    else
      attrib_needed! :thumbdata, false
      errors.add :url, "couldn't be read (errcode = #{errcode})" if errcode != 0
    end
  end

  # Provide the phony (but unique) URL that's used for a data-only image
  def self.fake_url
    randstr = (0...8).map { (65 + rand(26)).chr }.join
    Time.new.to_s + randstr
  end

  # Is this a data-only reference?
  def fake_url?
    url =~ /^\d\d\d\d-/
  end

  def thumbdata
    self[:thumbdata]
  end

  def thumbdata=(val)
    write_attribute :thumbdata, val
  end

end
