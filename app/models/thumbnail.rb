require "RMagick"
require './lib/controller_utils.rb'
require "Domain"
class Thumbnail < ActiveRecord::Base
  attr_accessible :thumbsize, :thumbdata, :url, :site
  before_save :update_thumb
  
  # Try to fetch the thumbnail data for the record, presuming a valid URL
  # If the fetch fails, leave the thumbdata as nil
  def update_thumb(force = false)
    self.thumbdata = nil if force
    unless thumbdata =~ /^data:/
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
          if (img.columns < thumbsize || img.rows < thumbsize) 
            thumb = img.resize_to_fit thumbsize
          else
            thumb = img.resize_to_fill thumbsize 
          end
          thumb.format = "JPEG"
          quality = 20
          thumb.write("thumb#{id.to_s}-M#{quality.to_s}.jpg") { self.quality = quality } unless true # Rails.env.production?
          self.thumbdata = "data:image/jpeg;base64," + Base64.encode64(thumb.to_blob{self.quality = quality })
        rescue Exception => e
        end
      end
      save if id
    end
    self
  end
  
  # Use a path and site to fetch a thumbnail record, which may match a priorly cached one
  def self.acquire(site, path)
    if url = valid_url(site, path)
      Thumbnail.find_or_create_by_url url
    end
  end
  
  # Does a thumbnail reflect the given site and path?
  def matches? (site, path)
    (full_url = valid_url(site, path)) && (full_url == url)
  end

end
