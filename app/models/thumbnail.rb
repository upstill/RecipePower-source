require "RMagick"
require "Domain"
# TODO: remove this defunct model, with controllers and views
class Thumbnail < ActiveRecord::Base
  attr_accessible :thumbsize, :thumbdata, :url, :site # , :picAR
  # before_save :update_thumb
  
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
          if img.columns > thumbsize
            scalefactor = thumbsize.to_f/img.columns
            thumb = img.scale(scalefactor)
          else
            thumb = img
          end
          thumb.format = 'PNG'
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
      Delayed::Job.enqueue(tn, priority: 3)  unless tn && tn.thumbdata
      tn
    end
  end

end
