class PicPickerController < ApplicationController

  def new
    %w{picurl pageurl golinkid fallback_img}.each { |key| self.instance_variable_set(:"@#{key}", params[key] ) }
    if (picref = params[:picrefid] ? Reference.find(params[:picrefid].to_i) : nil)
      # Get the url and the data (if any) from the reference
      @picurl = picref.url
      @picdata = picref.thumbdata
    end
    @picdata ||= @picurl || @fallback_img || "NoPictureOnFile.png"
  end
end
