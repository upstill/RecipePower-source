require "RMagick"
require "Domain"
class Thumbnail < ActiveRecord::Base
  attr_accessible :thumbsize, :thumbdata, :url, :site
  before_save :update_thumb
@@FileCount = 1
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
        begin
          img = Magick::Image::from_blob(response.body).first
          if (img.columns < thumbsize || img.rows < thumbsize) 
            thumb = img.resize_to_fit thumbsize
          else
            thumb = img.resize_to_fill thumbsize 
          end
          thumb.format = "JPEG"
          thumb.write("thumb#{@@FileCount.to_s}.jpg") unless Rails.env.production?
          @@FileCount = @@FileCount + 1
          self.thumbdata = "data:image/jpeg;base64," + Base64.encode64(thumb.to_blob)
        rescue Exception => e
          return self.bad_url
        end
      when 400, 403, 404 # Bad request, forbidden or not found => reject the URL entirely
        return self.bad_url
      else
        self.thumbdata = url # Maybe the image can be fetched by the client
      end
      save if id
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
  
  # Somehow this thumbnail has a bad URL: mark it thus
  def bad_url
    @@BadURL = Thumbnail.find_or_create_by_url(url: "http://www.recipepower.com/assets/BadPicURL.png")
  end
  
  # Thumbnail is BadURL message
  def bad_url?
    url == "http://www.recipepower.com/assets/BadPicURL.png"
  end
  
  # Thumbnail is no-picture message
  def missing_picture?
    url == "http://www.recipepower.com/assets/MissingPicture.png"
  end

end
