require "RMagick"
require "Domain"
class Thumbnail < ActiveRecord::Base
  attr_accessible :thumbht, :thumbwid, :thumbdata, :url, :site
  before_save :update_thumb
  
  # Set the url for the record, returning either the record or the invalid-URL record
  # Bust the cache if the url changes
  def validate_url(site, path)
    # If no path, we just use the "Missing Picture" thumb
    current_domain = "www.recipepower.com"
    oldURL = url
    rcd = 
    Thumbnail.find_or_create_by_url(path.blank? ? 
      "http://#{current_domain}/assets/MissingPicture.png" :
      (Site.valid_url(site, path) || "http://#{current_domain}/assets/BadPicURL.png"))
    thumbdata = nil if rcd == self && url != oldURL
    rcd
  end

  # Try to fetch the thumbnail data for the record, presuming a valid URL
  # If the fetch fails, return a suitable placeholder thumbnail
  def update_thumb
    if thumbdata.blank?
      self.status = nil
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
      
      case status
      when 200 # Success!
        img = Magick::Image::from_blob(response.body).first
        thumb = img.resize_to_fill 120
        thumb.format = "JPEG"
        thumb.write "thumb.jpg" unless Rails.env.production?
        self.thumbdata = "data:image/jpeg;base64," + Base64.encode64(thumb.to_blob)
      when 400, 403, 404 # Bad request, forbidden or not found => reject the URL entirely
        debugger
        rcd = Thumbnail.where(url: "http://www.recipepower.com/assets/BadPicURL.png")[0] 
        rcd ||= Thumbnail.new(url: "http://www.recipepower.com/assets/BadPicURL.png")
        return rcd.update_thumb
      else
        self.thumbdata = url # Maybe the image can be fetched by the client
      end
    end
    self
  end
  
  # Use a path and site to fetch a thumbnail record, which may match a priorly cached one
  def self.acquire(site, path)
    # If no path, we just use the "Missing Picture" thumb
    Thumbnail.find_or_create_by_url(path.blank? ? 
      "http://www.recipepower.com/assets/MissingPicture.png" :
      (Site.valid_url(site, path) || "http://www.recipepower.com/assets/BadPicURL.png")).update_thumb
  end
  
=begin  
  # Return a new record for the site and path, or invalid-URL record if not valid
  def self.match(site, path)
    self.new.validate_url(site, path)
  end
  
  # Validate the cache against the site and path, returning an invalid-URL record or an updated
  # cache. We guarantee the resulting record to have a valid data cache
  def fetch(site=nil, path=nil)
    # validate the URL if path is present
    (path ? validate_url(site, path) : self).update_thumb # ...and update the thumbnail
  end
=end
  
  # Thumbnail is BadURL message
  def badURL?
    url == "http://www.recipepower.com/assets/BadPicURL.png"
  end
  
  # Thumbnail is no-picture message
  def missingPicture?
    url == "http://www.recipepower.com/assets/MissingPicture.png"
  end

end
