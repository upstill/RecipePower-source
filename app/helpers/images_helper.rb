module ImagesHelper

  # Define an image tag which responds reasonably to image failure using pics.js.
  # url_or_object: either a string, or a decorator, or an object (as long as it responds to imgdata and fallback_imgdata)
  # opts_in are passed to the image_tag, except:
  # - :fill_mode causes the image to be dynamically fit within its container if truthy
  # - :explain causes a bogus image to be replaced with NoPictureOnFile.png or BadPicURL.png 
  # - :fallback_img forces an image tag to be produced if there is no url
  #   -- if the option value is a string, it's used as specified
  #   -- otherwise, it's fetched from url_or_object
  def image_with_error_recovery url_or_object, opts_in={}
    options = opts_in.clone
    fallback_img = options.delete :fallback_img
    if url_or_object.is_a? String
      url = url_or_object
    else
      # Extract the url from the object
      url = url_or_object.imgdata
      fallback_img = url_or_object.respond_to?(:fallback_imgdata) && image_path(url_or_object.fallback_imgdata) unless !fallback_img || fallback_img.is_a?(String)
    end
    options[:alt] ||= fallback_img if fallback_img.is_a?(String) && fallback_img.present?  # Had better be a string if the url was a string

    # The :fill_mode option requests the image be resized to fit its container
    if fill_mode = options.delete(:fill_mode)
      options[:class] = "#{options[:class]} #{fill_mode}" # Add fill-mode indicator to class
      # options[:class] = "#{options[:class]} fitPic #{fill_mode}" # Add fitPic class and mode indicator
      # options[:onload] = 'doFitImage(event);'  # Fit the image onload
    end

    options[:data] ||= {}
    if options.delete :explain
      url = fallback_img if url.blank? && fallback_img.is_a?(String)
      options[:data] = {
          emptyurlfallback: (options.delete(:emptyurlfallback) || image_path('NoPictureOnFile.png')),
          bogusurlfallback: (options.delete(:bogusurlfallback) || image_path('BadPicURL.png'))
      }.merge options[:data]
    end
    options[:data][:handle_empty] = options.delete(:handle_empty) if options[:handle_empty]

    # if url.present? || fallback_img
      options[:alt] ||= 'Image Not Accessible'
      options[:onError] ||= 'onImageError(this);'
      image_tag ((url.present? && url) || (fallback_img.is_a?(String) && fallback_img) || ''), options
    # end
  end

  # Define a div or other content tag for enclosing an image.
  # options :fill_mode, :explain and :fallback_img are passed to image_with_error_recovery
  # Others are passed to content_tag
  def image_enclosure decorator, tag=:div, opts_in={}
    if tag.is_a? Hash
      tag, opts_in = :div, tag
    end
    image_options = opts_in.clone
    enclosure_options = image_options.slice! :fill_mode, :explain, :fallback_img, :handle_empty
    fill_mode = (image_options[:fill_mode] ||= 'fixed-width')
    if image = image_with_error_recovery(decorator, image_options )
      style = case fill_mode
                when "fixed-width"
                  "width: 100%; height: auto;"
                when "fixed-height"
                  "width: auto; height: 100%;"
              end if tag.to_sym == :div
      enclosure_options[:style] = style if style
      content_tag tag, link_to(image, decorator.url), enclosure_options
    end
  end

  # Provide an image tag that resizes according to options[:fill_mode].
  # We give the tag an id according to the decorator, and an alt;
  # Both of those may be explicitly provided with the options
  # OBSOLETE (unused, folded into image_with_error_recovery)
  def resizing_image_tag decorator, fallback=false, options={}
    if fallback.is_a?(Hash)
      fallback, options = false, fallback
    end
    begin
      if (url = decorator.imgdata).present? || (fallback && (url = image_path(decorator.fallback_imgdata)).present?)
        image_with_error_recovery url,
                                  alt: (options[:alt] || "Image Not Accessible"),
                                  id: (options[:id] || dom_id(decorator)),
                                  class: "#{options[:class]} #{options[:fill_mode] || 'fixed-width'}"
      end
    rescue Exception => e
      if url
        url = "data URL" if url =~ /^data:/
      else
        url = "nil URL"
      end
      content =
          "Error rendering image #{url.truncate(255)} from "+ (decorator ? "#{decorator.human_name} #{decorator.id}: '#{decorator.title}'" : "null #{decorator.human_name}")
      ExceptionNotification::Notifier.exception_notification(request.env, e, data: {message: content}).deliver
      content
    end
  end

  # Sort out a suitable URL to stuff into an image thumbnail, enclosing it in a div
  # of the class given in options. The image will stretch either horizontally (fill_mode: "fixed-height")
  # or vertically (fill_mode: "fixed-width") within the dimensions given by the enclosing div.
  # OBSOLETE: folded into image_enclosure
  def safe_image_div decorator, fallback=false, options = {}
    if fallback.is_a?(Hash)
      fallback, options = false, fallback
    end
    fill_mode = options.delete(:fill_mode) || 'fixed-width'
    if image = image_with_error_recovery(decorator, explain: !fallback, fill_mode: fill_mode)
      style = case fill_mode
                when "fixed-width"
                  "width: 100%; height: auto;"
                when "fixed-height"
                  "width: auto; height: 100%;"
              end
      options[:style] = style if style
      content_tag :div, link_to(image, decorator.url), options
    end
  end

end
