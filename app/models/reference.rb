class Reference < ActiveRecord::Base

  include Referrable
  include Typeable

  attr_accessible :reference_type, :type, :url, :affiliate_id

  validates_uniqueness_of :url, :scope => :type

  typeable( :reference_type,
    Article: ["Article", 1],
    Newsitem: ["News Item", 2],
    Tip: ["Tip", 4],
    Video: ["Video", 8],
    Definition: ["Glossary Entry", 16],
    Homepage: ["Home Page", 32],
    Product: ["Product", 64],
    Offering: ["Offering", 128],
    Recipe: ["Recipe", 256],
    Image: ["Image", 512],
    Site: ["Site", 1024],
    Event: ["Event", 2048]
  )

  public

  # By default, the reference gives up its url, but may want to use something else, like image data
  def digested_reference
    url
  end

  # Convert back and forth between class and typenum (for heeding type selections)
  def self.type_to_class typenum=0
    return Reference if !typenum || typenum == 0
    ((self.typesym(typenum) || "").to_s+"Reference").constantize
  end

  def typesym
    self.class.to_s.sub( 'Reference', '' ).to_sym
  end

  def typenum
    return 0 if self.class == Reference
    Reference.typenum typesym
  end

  # Index a Reference by URL or URLs, assuming it exists (i.e., no initialization or creation)
  def self.lookup url_or_urls, partial=false
    if self.affiliate_class
      (url_or_urls.is_a?(Array) ? url_or_urls : [url_or_urls]).map { |url| normalize_url url }.uniq.collect { |url|
        unless (normalized = normalize_url url).blank? # Check for non-empty URL
          if partial
            list = Reference.where "type = '#{self.to_s}' and url LIKE ?", normalized+"%"
          else
            list = Reference.where type: self.to_s, url: normalized # Check for non-empty URL
          end
          list
        end
      }.flatten.compact.uniq
    end
  end

  # Lookup the affiliate(s) that match the given url(s).
  # 'by_site' stipulates that an initial substring match suffices
  def self.lookup_affiliates url_or_urls, partial=false
    if self.affiliate_class # Referents need not apply (unknown affiliate class)
      unless (ids = self.lookup(url_or_urls, partial).map(&:affiliate_id).compact.uniq).empty?
        return self.affiliate_class.find ids
      end
    end
    []
  end

  def self.lookup_affiliate url_or_urls, partial=false
    if self.affiliate_class # Referents need not apply (unknown affiliate class)
      unless (ids = self.lookup(url_or_urls, partial).map(&:affiliate_id).compact.uniq).empty?
        self.affiliate_class.find ids.first
      end
    end
  end

  # Return a (perhaps unsaved) reference for the given url
  # params containts attribute name-value pairs for initializing the reference
  # AND ALSO an :affiliate, the object the reference is about (e.g., Site, Recipe...)
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
      return [ self.create_with(url: url, canonical: true).find_or_create_by( type: "ImageReference", thumbdata: url) ]
    end
    params[:type] ||= self.to_s

    # Normalize the url for lookup
    normalized = normalize_url url
    if normalized.blank? # Check for non-empty URL
      ref = self.new params # Initialize a record just to report the error
      ref.errors.add :url, "can't be blank"
      refs = [ref]
    else
      refs = Reference.where( type: params[:type], :url => normalized).order "canonical DESC"
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
          refs = Reference.where(type: params[:type], url: redirected).to_a
          refs = [ Reference.new(type: params[:type], url: redirected) ] if refs.empty?
          (canonical = refs.first).canonical = true # Make the redirected reference be canonical, and first
          # Now we create a new reference, aliased to that of the canonical reference by making their affiliate id's the same
          refs << Reference.new(type: params[:type], :url => normalized, affiliate_id: canonical.affiliate_id ) if normalized != redirected
        end
      end
    end
    refs
  end

  # Assert a reference to the given URL, linking back to a referent
  def self.assert(uri, tag_or_referent, type=:Definition )
    refs = "#{type}Reference".constantize.find_or_initialize uri
    refs.each { |me| me.assert tag_or_referent, type } if refs.first.errors.empty?
    refs.first
  end

  def assert tag_or_referent, type=:Definition
    rft =
        case tag_or_referent
          when Tag
            Referent.express tag_or_referent
          else
            tag_or_referent
        end
    if rft
      self.referents << rft unless referents.exists?(id: rft.id)
      save
    end
  end

  # Ping the reference's URL, setting its canonical bit appropriately
  def ping
    self.url = normalize_url(url) unless self.canonical # We keep the canonical url exactly as redirected (no normalization)
    if redirected = test_url(url)
      unless self.canonical = (redirected == url)
        # We need a separate canonical record
        can = self.dup
        can.canonical = true
        can.url = redirected
        can.save
      end
    end
    self.save
  end

  # Get data from the reference via HTTP
  def fetch
    def get_response url
      self.status = response = nil
      begin
        uri = URI.parse(url)
        if uri.host &&
            uri.port &&
            (http = Net::HTTP.new(uri.host, uri.port)) &&
            (request = Net::HTTP::Get.new(uri.request_uri))
          response = http.request(request)
          self.status = response.code.to_i
        else # Invalid URL
          self.status = 400
        end
      rescue Exception => e
        # If the server doesn't want to talk, we assume that the URL is okay, at least
        case e
          when Errno::ECONNRESET
            self.status = 401
          else
            self.status = -1  # Undifferentiated error during fetch, possibly a parsing problem
        end
      end
      response
    end

    # get_response records the status of the last HTTP access in self.status
    tried = {}
    next_try = url
    until tried[next_try]
      tried[next_try] = true
      response = get_response next_try
      case status
        when 200
          return response.body
        when 301, 302 # Redirection
          next_try = response.header["location"]
        when 401 # Unauthorized
          next_try.sub! /^https/, 'http'
      end
    end
  end

  # Give a reference an affiliate object (if any), raising an exception if one already exists, or types don't match
  def affiliate= affiliate
    if affiliate
      if affiliate.class != affiliate_class # self.class.to_s != "#{affiliate.class.to_s}Reference"
        raise "Attempt to affiliate #{self.class.to_s} reference with #{affiliate.class} object."
      elsif affiliate_id && (affiliate_id != affiliate.id)
        raise "Attempt to create ambiguous reference by asserting new affiliate"
      else
        self.affiliate_id = affiliate.id
      end
    end
  end

  # Point the references affiliated with one entity to another, presumably b/c the old one is going away.
  # It is an error if they aren't of the same type
  def self.redirect old_affiliate, new_affiliate

  end

  protected

  # Extract the affiliated object, according to the type of reference
  def affiliate
    self.affiliate_class && affiliate_id && self.affiliate_class.find(affiliate_id)
  end

  # What's the class of the associated affiliate?
  def affiliate_class
    self.class.affiliate_class
  end

  # What's the class of the associated affiliate (subclasses of Reference only)
  def self.affiliate_class
    self.to_s.sub(/Reference$/, '').constantize unless (self == Reference)
  end

end

class ArticleReference < Reference

end

class NewsitemReference < Reference

end

class TipReference < Reference

end

class VideoReference < Reference

end

class DefinitionReference < Reference

end

class HomepageReference < Reference

end

class ProductReference < Reference

end

class OfferingReference < Reference

end

class RecipeReference < Reference
  belongs_to :recipe, foreign_key: "affiliate_id"

  def self.lookup_recipe url_or_urls, by_site=false
    self.lookup_affiliate url_or_urls, by_site
  end

  def self.lookup_recipes url, by_site=false
    self.lookup_affiliates url, by_site
  end
end

class ImageReference < Reference
  # An Image Reference maintains a local thumbnail of the image
  attr_accessible :thumbdata, :status

  def self.lookup_image url
    self.lookup_affiliate url
  end

  def self.lookup_images url, by_site=false
    self.lookup_affiliates url, by_site
  end

  def self.find_or_initialize url, params={}
    candidates = super
    candidates.map &:fetchable
    # Check all the candidates for a data: URL, and return the canonical one or the first one, if none is canonical
    [ (candidates.find &:canonical || candidates.first) ]
  end

  # Provide suitable content for an <img> element: preferably data, but possibly a url or even (if the data fetch fails) nil
  def imgdata
    url_usable = fetchable # fetchable may set the thumbdata
    thumbdata || url # (url if url_usable)
  end
  # alias_method :digested_reference, :imgdata

  # Try to fetch the thumbnail data for the record. Status code assigned in ImageReference#fetchable and Reference#fetch
  def perform
    unless thumbdata && (thumbdata =~ /^data:/)
      logger.info ">>>>>>>>>>>>>>>>>>>>>>>>>>>>> Acquiring Thumbnail data on url '#{url}' >>>>>>>>>>>>>>>>>>>>>>>>>"
      self.thumbdata = nil
      self.status = 0 if self.status == -2
      if fetchable(false) && response_body = fetch # Attempt to get data at the other end of the URL
        begin
          img = Magick::Image::from_blob(response_body).first
          if img.columns > 200
            scalefactor = 200.0/img.columns
            thumb = img.scale(scalefactor)
          else
            thumb = img
          end
          thumb.format = "JPEG"
          quality = 20
          thumb.write("thumb#{id.to_s}-M#{quality.to_s}.jpg") { self.quality = quality } unless true # Rails.env.production?
          self.thumbdata = "data:image/jpeg;base64," + Base64.encode64(thumb.to_blob{self.quality = quality })
        rescue Exception => e
          logger.debug "Failed to parse image data for ImageReference#{id}: #{url} (#{e})"
          self.status = -2 # Bad data
        end
      end
      save  # Save the status code, if nothing else
    end
    self
  end

  def fetchable queue_up=true
    # Nominally, an ImageReference records a URL plus its expansion into a thumbnail.
    # However, the URL may come in as data: already, which makes the indexer unhappy.
    # In this case, we transfer the data to thumbdata and set the URL to a pseudo-random key (to satisfy the uniqueness constraint on References)
    if url =~ /^data:/
      self.thumbdata = url
      randstr = (0...8).map { (65 + rand(26)).chr }.join
      self.url = Time.new.to_s + randstr
      save
      false
    else
      # Check on the thumbdata, queuing it up for caching if not present
      unless thumbdata && (thumbdata =~ /^data:/)
        if [
            # Don't retry on these status codes
            -2, # Got unparseable data from the request
            400, # Bad Request
            403, # Forbidden
            410, # Gone
        ].include? status
          false
        else
          Delayed::Job.enqueue(self, priority: 5) if queue_up
          true # Assume the url is valid
        end
      end
    end
  end

end

# Site references are indexed by the initial substring of a url
# (specifically, the protocol, domain and host, plus any path used to distinguish different sites with the same host).
class SiteReference < Reference
  belongs_to :site, foreign_key: "affiliate_id"
  before_save :fix_host

  # Return the definitive url for a given url. NB: This will only be the site portion of the URL
  def self.canonical_url url
    normalized_link = normalize_url(url).sub(/\/$/,'')
    if host_url = host_url(normalized_link)
      # Candidates are all sites with a matching host
      matches = Reference.where(type: "SiteReference").where('url ILIKE ?', "#{host_url}%")
      matches.map(&:url).inject(nil) { |result, this|
        # If more than one match, seek the longest
        result = this if normalized_link.start_with?(this) && (!result || (result.length < this.length))
        result
      } || host_url
    else
      puts "Ill-formed url: '#{url}'"
      nil
    end
  end

  def self.lookup_site url
    self.lookup_affiliate self.canonical_url(url)
  end

  def self.lookup_sites url
    self.lookup_affiliates self.canonical_url(url)
  end

  # Generelly we reduce the find to the shortest available subpath of a url
  def self.find_or_initialize url_or_urls, in_full=false
    urls = (url_or_urls.is_a?(String) ? [url_or_urls] : url_or_urls)
    urls = urls.map { |url| canonical_url url }.compact.uniq unless in_full
    urls.each { |url|
      siterefs = self.where url: url # Lookup the site on the exact url
      return siterefs unless siterefs.empty?
    }
    super urls.first unless urls.empty?
  end

  protected

  # Before saving, save the host from the url
  def fix_host
    if host.blank?
      begin
        uri = URI(url)
        logger.debug (self.host = uri.host.match(/\w*\.\w*$/)[0])
      rescue
        return false
      end
    end
    true
  end

end

class EventReference < Reference

end
