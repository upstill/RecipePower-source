module ImagesHelper

  # Define an image tag which responds reasonably to image failure using pics.js.
  # url_or_object: either a string, or a decorator, or an object (as long as it responds to imgdata and fallback_imgdata)
  # opts_in are passed to the image_tag, except:
  # - :fill_mode causes the image to be dynamically fit within its container if truthy
  # - :explain causes a bogus image to be replaced as follows:
  #     -- non-existent URL shows opts_in[:emptyurlfallback] or NoPictureOnFile.png
  #     -- bad URL shows opts_in[:bogusurlfallback] or BadPicURL.png
  # - :fallback_img forces an image tag to be produced if there is no url
  #   -- if the option value is a string, it's used as specified
  #   -- otherwise, a true value means to fetch it from url_or_object
  def image_with_error_recovery url_or_object, opts_in={}
    options = opts_in.clone
    fallback_img = options.delete :fallback_img

    url =
    if url_or_object.is_a? String
      url_or_object
    else
      # Use the object to provide a fallback image
      fallback_img = image_path(url_or_object.fallback_imgdata) if (fallback_img == true) && url_or_object.respond_to?(:fallback_imgdata)
      # Extract the url from the object
      url_or_object.imgdata
    end

    # Ignore the fallback flag unless it's a string
    fallback_img = nil unless fallback_img.is_a? String

    options[:data] ||= {}
    # The :fill_mode option requests the image be resized to fit its container
    if fill_mode = options.delete(:fill_mode)
      options[:class] = "#{options[:class]} #{fill_mode}" # Add fill-mode indicator to class
      # options[:onload] = 'doFitImage(event);'  # Fit the image on load
    end

    if options.delete :explain
      options[:data] = {
          emptyurlfallback: (fallback_img.if_present || image_path('NoPictureOnFile.png')),
          bogusurlfallback: (options.delete(:bogusurlfallback) || image_path('BadPicURL.png'))
      }.merge options[:data]
    end
    options[:data][:handle_empty] = options.delete(:handle_empty) if options[:handle_empty]

    options[:alt] ||= 'Image Not Accessible'
    options[:onError] ||= 'onImageError(this);'
    image_tag (url.if_present || fallback_img || ''), options
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
    nolink = image_options.delete :nolink
    enclosure_options = image_options.slice! :fill_mode, :explain, :fallback_img, :handle_empty

    if content = image_with_error_recovery(decorator, image_options )
      if tag.to_sym == :div
        enclosure_options[:style] = enclosure_options[:style].to_s +
            (image_options[:fill_mode] || '') == 'fixed-height' ? 'width: auto; height: 100%;' : 'width: 100%; height: auto;'
      end
      content = link_to_submit(content, decorator.object) unless nolink
      content_tag tag, content, enclosure_options
    end
  end

  def image_from_decorator decorator, options={}
    image_with_error_recovery decorator,
                              {
                                  class: decorator.image_class,
                                  fallback_img: decorator.object.is_a?(User),
                                  fill_mode: 'fixed-width'
                              }.merge(options)
  end

  def labelled_avatar decorator, options={}
    content_tag(:div,
                image_from_decorator(decorator, options),
                class: 'owner-pic pic-box') +
    content_tag(:span, homelink(decorator), class: 'owner-name')
  end

  def video_embed vidlink
    iframe = content_tag :iframe,
                         '',
                         src: vidlink,
                         frameborder: 0,
                         height: '100%',
                         width: '100%'
    vbelement = content_tag :div, iframe, id: 'vbelement'
    vbdummy = content_tag :div, vbelement, id: 'vbdummy'
    content_tag :div, vbdummy, id: 'vidbox'
=begin
  <div id="vidbox">
    <div id="vbdummy">
      <div id="vbelement">
        <iframe width="100%" height="100%" src="<%= vid %>" frameborder="0"></iframe>
      </div>
    </div>
  </div>
=end

  end
end
