module ImagesHelper

  def image_with_error_recovery url, options={}
    unless options[:leave_blank]
      options[:data] = {
          emptyurlfallback: image_path('NoPictureOnFile.png'),
          bogusurlfallback: image_path('BadPicURL.png')
      }.merge(options[:data] || {})
    end
    image_tag url, {alt: "Image Link is Broken"}.merge(options.except(:leave_blank)).merge(onError: "onImageError(this);")
  end

  # Declare an image which gets resized to fit upon loading
  # id -- used to define an id attribute for this picture (all fitpics will have class 'fitPic')
  def image_with_resize picurl, options={}
    image_with_error_recovery picurl || "",
                              options.merge(class: "#{options[:class]} fitPic", # Add fitPic class
                                            onload: 'doFitImage(event);')
  end

end
