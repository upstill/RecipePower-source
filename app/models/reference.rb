class Reference < ActiveRecord::Base

  include Referrable
  include Typeable

  attr_accessible :reference_type, :type, :url

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

  def self.assert(uri, tag_or_referent, type=:Definition )
    if (me = self.find_or_initialize uri).errors.empty?
      me.assert tag_or_referent, type
    end
    me
  end

  def assert tag_or_referent, type=:Definition
    return nil unless rft =
        case tag_or_referent
          when Tag
            Referent.express tag_or_referent
          else
            tag_or_referent
        end
    self.referents << rft unless referents.exists?(id: rft.id)
    self.reference_type = Reference.typenum type
    save
  end

  # Index a Reference by a URL. NB: This WILL resort to a ping on the URL if no reference is found directly on the normalized url
  # In general it is MUCH faster to find the reference for an object via its :reference association
  def self.by_link url
    normalized = normalize_url url
    unless normalized.blank? # Check for non-empty URL
      Reference.where(type: self.to_s, url: normalized).first ||
      ((redirected = test_url(url)) &&
        Reference.where(type: self.to_s, url: redirected).first)
    end
  end

  # Return a (perhaps unsaved) reference for the given url
  def self.find_or_initialize url, params = {}

    # URL may be passed as a parameter or in the params hash
    if url.is_a? Hash
      params = url
      url = params[:url]
    else
      params[:url] = url
    end
    # IMPORTANT! the type of reference is determined from the invoked class if not given specifically
    params[:type] ||= self.to_s
    # It is an error to present an affiliate whose type doesn't match the reference class
    if (affiliate = params.delete :affiliate)
      if params[:type] && (params[:type] != (affiliate.class.to_s+"Reference"))
        raise "Attempt to establish #{params[:type]} for #{affiliate.class.to_s} affiliate."
      else
        params[:type] = affiliate.class.to_s+"Reference"
      end
    end
    # Normalize the url for lookup
    normalized = normalize_url url
    if normalized.blank? # Check for non-empty URL
      obj = self.new params # Initialize a record just to report the error
      obj.errors.add :url, "can't be blank"
    elsif obj = Reference.where(type: params[:type], :url => normalized).first
      # Reference already exists under the normalized url
      obj.affiliate = affiliate
    elsif !(redirected = test_url url)
      obj = self.new params # Initialize a record just to report the error
      obj.errors.add :url, "\'#{url}\' doesn't seem to be a working URL. Can you use it as an address in your browser?"
    else
      # No reference to be found under the given (normalized) URL -> create one, and possibly its root reference as well
      # The goal is to ensure access through any given link that resolves to the same URL after normalization and any redirection.
      # We achieve this by creating references, each pointing to the same affiliate, on at most two URLS:
      #  1) the original URL (after normalization), so identical references wind up with the identical affiliate; and
      #  2) the URL as redirected by the site in question (and again normalized), so that future URLS that redirect
      #   to the same place get to the same affiliate.
      # NB: It's true that we could simply use the redirected URL for looking up a reference, but that would require
      #  hitting the site every time that URL was referenced. This way, we only have to take the redirection once, and
      #  the Reference class remembers the mapping.
      root_ref = Reference.where(type: params[:type], url: redirected).first ||
                 Reference.new(type: params[:type], url: redirected)
      root_ref.canonical = true
      obj = (normalized == redirected) ? root_ref : Reference.new(type: params[:type], :url => normalized)
      # Propagate affiliate to any new reference
      obj.affiliate_id = root_ref.affiliate_id

      # Attach the affiliate, if given and doesn't collide with existing affiliate
      if affiliate
        obj.affiliate = affiliate
        if root_ref != obj
          root_ref.affiliate = affiliate
          root_ref.save
        end
      elsif root_ref.affiliate_id # Give the new object the same affiliate as any priorly existing root_ref
        obj.affiliate_id = root_ref.affiliate_id
      end
    end
    obj
  end

  def self.find_or_create url, params={}
    obj = self.find_or_initialize url, params
    obj.save unless obj.id || obj.errors.any?
    obj
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

  # Get data from the reference
  def fetch
    def get_response url
      self.status = response = nil
      begin
        uri = URI.parse(url)
=begin
        req = Net::HTTP.new(url.host, url.port)
        partial = url.path + ((query = url.query) ? "?#{query}" : "")
        code = req.request_head(partial).code.to_i
        # Redirection codes
        [301, 302].include?(code) ? req.request_head(partial).header["location"] : code
=end
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
            self.status = -1
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
      if self.class.to_s != "#{affiliate.class.to_s}Reference"
        raise "Attempt to affiliate #{self.class.to_s} reference with #{affiliate.class} object."
      elsif affiliate_id && (affiliate_id != affiliate.id)
        raise "Attempt to create ambiguous reference by asserting new affiliate"
      else
        self.affiliate_id = affiliate.id
      end
    end
  end

  # Extract the affiliated object, according to the type of reference
  def affiliate
    if affiliate_id && (affiliate_type = self.class.to_s.sub(/Reference$/, ''))
      affiliate_type.constantize.find(affiliate_id)
    end
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

end

class ImageReference < Reference
  # An Image Reference maintains a local thumbnail of the image
  attr_accessible :thumbdata, :status

  def check_url
    # Nominally, an ImageReference records a URL plus its expansion into a thumbnail.
    # However, the URL may come in as data: already, which makes the indexer unhappy.
    # In this case, we transfer the data to thumbdata and set the URL to a pseudo-random key (to satisfy the uniqueness constraint on References)
    if url =~ /^data:/
      self.thumbdata = url
      randstr = (0...8).map { (65 + rand(26)).chr }.join
      self.url = Time.new.to_s + randstr
      false
    else
      true # Assume the url is valid
    end
  end

  def self.find_or_initialize url, params={}
    candidate = super
    candidate.check_url
    candidate
  end

  # Try to fetch the thumbnail data for the record, presuming a valid URL
  def perform
    unless thumbdata && (thumbdata =~ /^data:/)
      logger.info ">>>>>>>>>>>>>>>>>>>>>>>>>>>>> Acquiring Thumbnail data on url '#{url}' >>>>>>>>>>>>>>>>>>>>>>>>>"
      # If the URL is already data:, copy it over to the thumbdata and
      if check_url && response_body = fetch # Attempt to get data at the other end of the URL
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
          save
        end
      end
    end
    self
  end

end

# Site references can be accessed by matching a URL which may be much longer than the reference URL
class SiteReference < Reference
  belongs_to :site, foreign_key: "affiliate_id"

  # Find and return the SiteReference for the named link
  def self.by_link link
    # Sanitize and normalize the URL
    if !link.blank? && canonical_url = self.canonical_url(link)
      sr = self.find_or_create canonical_url
      sr.site ||= Site.create(:sample=>sr.url, :reference=>sr)
      sr
    end
  end

  # Return the definitive url for a given link. NB: This will only be the site portion of the URL, per by_link
  def self.canonical_url link
    # We tread carefully because several sites could share the same host. In that case, we return the longest path
    # that matches the link. If there are none such, we return the host url itself.
    normalized_link = normalize_url(link)
    if host_url = host_url(normalized_link)
      # Candidates are all sites with a matching host
      matches = Reference.where(type: "SiteReference").where('url ILIKE ?', "#{host_url}%")
      longest = matches.first && matches.inject(nil) { |result, this|
        # If more than one match, seek the longest
        normalized_link.start_with?(this.url) &&
        (!result || (result.url.length < this.url.length)) ? this : result
      }
      longest ? longest.url : host_url
    else
      puts "Ill-formed link: '#{link}'"
      nil
    end
  end
end
