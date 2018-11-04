require 'rmagick' unless Rails.env.development?
require 'open-uri'
require 'mechanize'
require 'fileutils'
require 'array_utils'

class Reference < ApplicationRecord

  include Referrable # Can be linked to a Referent

  include Backgroundable

  backgroundable :status

  # attr_accessible :type, :url, :filename, :link_text

  validates_uniqueness_of :url, :scope => :type

  public

  # By default, the reference gives up its url, but may want to use something else, like image data
  def digested_reference
    url
  end

  # Index a Reference by URL or URLs, assuming it exists (i.e., no initialization or creation)
  def self.lookup url_or_urls, partial=false
    q, urls = self.querify(url_or_urls, partial)
    urls.present? ? self.where(q, *urls) : self.none
  end

  # private

  # Craft a query string and an array of urls, suitable for a #where call
  # 'http://ganga.com/upchuck' -> [ '"references"."url" ILIKE ?', [ 'http://ganga.com/upchuck%' ]]
  # [ 'http://ganga.com/upchuck' ] -> [ '"references"."url" ILIKE ?', ['http://ganga.com/upchuck%' ]]
  # [ 'http://ganga.com/upchuck', 'http://ganga.com' ] -> [ '"references"."url" ILIKE ?', ['http://ganga.com%' ]]
  # See test/unit/reference_test.rb for full test suite
  def self.querify url_or_urls, partial=false
    begin
      urls = normalize_urls url_or_urls, !partial
    rescue
      # If we can't normalize the urls, then use the un-normalized versions and hope for the best
      urls = (url_or_urls.is_a?(Array) ? url_or_urls : [url_or_urls])
      partial = true
    end
    if partial
      urls = condense_strings(urls).map { |url| url + '%' }
      q = (['"references"."url" ILIKE ?'] * urls.count).join(' OR ')
    else
      urls = urls.collect { |part| ['http://'+part, 'https://'+part] }.flatten
      q = urls.present? ? "\"references\".\"url\" in (#{(['?']*urls.count).join ', '})" : ''
    end
    [q, urls]
  end

  # Provide a relation for entities that match a string
  def self.strscopes matcher
    [
        (block_given? ? yield() : self).where('"references"."host" ILIKE ?', matcher)
    ]
  end

  # Return a (perhaps unsaved) reference for the given url
  # params contains name-value pairs for initializing the reference
  def self.find_or_initialize url, params = {}

    # URL may be passed as a parameter or in the params hash
    if url.is_a? Hash
      params = url
      url = params[:url]
    else
      params[:url] = url
    end
    # IMPORTANT! the type of reference is determined from the invoked class if not given specifically
    if url.match(/^data:/)
      return [ self.create_with(url: url, canonical: true).find_or_create_by( type: 'ImageReference', thumbdata: url) ]
    end
    params[:type] ||= self.to_s

    # Normalize the url for lookup
    normalized = normalize_url url
    if normalized.blank? # Check for non-empty URL
      ref = self.new params # Initialize a record just to report the error
      ref.errors.add :url, "can't be blank"
      refs = [ref]
    else
      ref_class = params[:type].constantize
      refs = ref_class.lookup(normalized).order 'canonical DESC'
      if refs.empty?
        # Need to create, if possible
        if !(redirected = test_url normalized) # Purports to be a url, but doesn't work
          refs = [self.new(params)] # Initialize a record just to report the error
          refs.first.errors.add :url, "\'#{url}\' doesn't seem to be a working URL. Can you use it as an address in your browser?"
        else
          # No reference to be found under the given (normalized) URL -> create one, and possibly its canonical reference as well
          # The goal is to ensure access through any given link that resolves to the same URL after normalization and any redirection.
          # We achieve this by creating references, each pointing to the same affiliate, on at most two URLS:
          #  1) the original URL (after normalization), so identical references wind up with the identical affiliate; and
          #  2) the URL as redirected by the site in question (and again normalized), so that future URLS that redirect
          #   to the same place get to the same affiliate.
          # NB: It's true that we could simply use the redirected URL for looking up a reference, but that would require
          #  hitting the site every time that URL was referenced. This way, we only have to take the redirection once, and
          #  the Reference class remembers the mapping.
          refs = ref_class.lookup(redirected).to_a
          # refs = Reference.where(type: params[:type], url: redirected).to_a
          refs = [ Reference.new(params.merge url: redirected) ] if refs.empty?
          (canonical = refs.first).canonical = true # Make the redirected reference be canonical, and first
          # Now we create a new reference, aliased to that of the canonical reference by making their affiliate id's the same
          refs << Reference.new(params.merge :url => normalized ) if normalized != redirected
        end
      end
    end
    refs
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
  end

end

class DefinitionReference < Reference

end

class HomepageReference < Reference

end

class ImageReference < Reference

  # An Image Reference maintains a local thumbnail of the image
  has_many :feeds, :foreign_key => :picture_id, :dependent => :nullify
  has_many :feed_entries, :foreign_key => :picture_id, :dependent => :nullify
  has_many :lists, :foreign_key => :picture_id, :dependent => :nullify
  has_many :products, :foreign_key => :picture_id, :dependent => :nullify
  has_many :recipes, :foreign_key => :picture_id, :dependent => :nullify
  has_many :sites, :foreign_key => :thumbnail_id, :dependent => :nullify
  has_many :users, :foreign_key => :thumbnail_id, :dependent => :nullify
  has_many :referments, :as => :referee, :dependent => :destroy
  has_many :referents, :through => :referments

  # Since the URL is never written once established, this method uniquely handles both
  # data URLs (for images with data only and no URL) and fake URLS (which are left in place for the latter)
  # NB: Implicit in here is the strategy for maintainng the data: since we only fetch reference
  # records by URL when assigning a URL to an entity, we only go off to update the data when
  # the URL is assigned
  def self.find_or_initialize url, params={}
    [
        case url
          when /^\d\d\d\d-/
            self.find_by url: url # Fake url previously defined
          when /^data:/
            self.find_by(thumbdata: url) ||
                begin
                  ref = self.new(url: self.fake_url)
                  ref.write_attribute :thumbdata, url
                  ref.status = :good
                  ref
                end
          when nil
          when ''
          else
            candidates = super # Find by the url
            # Queue the refs up to get data for the url as necessary and appropriate
            candidates.map &:bkg_launch
            # Check all the candidates for a data: URL, and return the canonical one or the first one, if none is canonical
            candidates.find &:canonical || candidates.first
        end
    ]
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

  # Try to fetch thumbnail data for the record. Status code assigned in ImageReference#fetchable and Reference#fetch
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
          logger.debug "Failed to parse image data for ImageReference #{id}: #{url} (#{e})"
          self.errcode = -2 # Bad data
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
    !definitive? && super
  end

  def bkg_land force=false
    !definitive? && super
  end

  def after dj
    self.status = (url =~ /^\d\d\d\d-/) || (errcode == 200) ? :good : :bad
    save
  end

  def thumbdata
    self[:thumbdata]
  end

  def thumbdata=(val)
    write_attribute :thumbdata, val
  end

end
