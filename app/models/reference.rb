class Reference < ActiveRecord::Base
  include Linkable
  linkable :url # A Reference has a unique (within the reference class) URL

  include Referrable
  include Typeable

  belongs_to :affiliate, polymorphic: true

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
    if (me = self.find_or_initialize( url: uri )).errors.empty?
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

end

class ImageReference < Reference
  # An Image Reference maintains a local thumbnail of the image
  attr_accessible :thumbdata, :status

  def self.find_or_initialize params
    paramsclone = params.clone.merge type: "ImageReference"
    super(paramsclone)
  end

  # Try to fetch the thumbnail data for the record, presuming a valid URL
  def perform
    unless thumbdata && (thumbdata =~ /^data:/)
      logger.info ">>>>>>>>>>>>>>>>>>>>>>>>>>>>> Acquiring Thumbnail data on url '#{url}' >>>>>>>>>>>>>>>>>>>>>>>>>"
      self.status = self.thumbdata = nil
      # self.picAR = nil
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

  # Use a path and site to fetch a thumbnail record,
  # which may or may not match a previously cached one,
  # and may or may not have valid cached data
  def self.acquire(site, path)
    if url = valid_url(path, site)
      tn = Thumbnail.find_or_create_by url: url
      Delayed::Job.enqueue tn unless tn && tn.thumbdata
      tn
    end
  end

end

class SiteReference < Reference

end
