class Reference < ActiveRecord::Base
  # include Linkable
  # key_linkable :url # A Reference has a unique (within the reference class) URL

  include Referrable
  include Typeable

  # belongs_to :affiliate, polymorphic: true

  attr_accessible :reference_type, :type

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
    Site: ["Site", 1024]
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

      # Attach the affiliate, if given and doesn't collide with existing affiliate
      root_ref.affiliate = affiliate
      obj.affiliate = affiliate
      root_ref.save if root_ref != obj
    end
    obj
  end

  # Ping the reference's URL, setting its canonical bit appropriately
  def ping
    self.url = normalize_url(url) unless self.canonical
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

  # Try to fetch the thumbnail data for the record, presuming a valid URL
  def perform
    unless thumbdata && (thumbdata =~ /^data:/)
      logger.info ">>>>>>>>>>>>>>>>>>>>>>>>>>>>> Acquiring Thumbnail data on url '#{url}' >>>>>>>>>>>>>>>>>>>>>>>>>"
      self.status = self.thumbdata = nil
      begin
        uri = URI.parse(url)
        if uri.host &&
            uri.port &&
            (http = Net::HTTP.new(uri.host, uri.port)) &&
            (request = Net::HTTP::Get.new(uri.request_uri))
          response = http.request(request)
          self.status = response.code
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

      if status == 200 # Success! Write the thumbdata if poss.
        begin
          img = Magick::Image::from_blob(response.body).first
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

  # Find and return the source site for the named link
  def self.by_link link
    # Sanitize and normalize the URL
    if canonical_url = self.canonical_url(link)
      Reference.where(type: self.to_s, url: canonical_url).first || super.find_or_initialize(host_url link)
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
      longest = matches[1..-1].inject(matches.first) { |result, this|
        # If more than one match, seek the longest
        (normalized_link.match this.url) && (result.url.length < this.url.length) ? this : result
      }
      longest ? longest.url : host_url
    else
      puts "Ill-formed link: '#{link}'"
      nil
    end
  end
end
