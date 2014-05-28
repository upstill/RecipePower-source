module PicPickerHelper

  # Show an image that will resize to fit an enclosing div, possibly with a link to an editing dialog
  # We'll need the id of the object, and the name of the field containing the picture's url
  def pic_field(form, pic_attribute, page_attribute=nil, options={})
    obj = form.object
    picurl = obj.send(pic_attribute)
    pageurl = page_attribute && obj.send(page_attribute)
    if home = options[:home]
      picurl = valid_url(picurl, home) unless picurl.blank?
      pageurl = valid_url(pageurl, home) if pageurl
    end
    input_id = obj.class.to_s.downcase + "_" + pic_attribute.to_s
    img_id = "rcpPic#{obj.id}"
    link_id = "golink#{obj.id}"
    pic_area = page_width_pic picurl, img_id, (options[:fallback_img] || "/assets/NoPictureOnFile.png")
    preview = content_tag :div,
                          pic_area+form.hidden_field(pic_attribute, rel: "jpg,png,gif", class: "hidden_text"),
                          class: "pic_preview"
    preview << content_tag(:div,
                           pic_preview_golink(pageurl, picurl, link_id, img_id, input_id),
                           class: "pic_picker_link") unless options[:nopicker]
    preview
  end

  # Bare-metal version of the pic preview widget, for use in a template file
  def pic_preview_widget page_url, img_url, entity_id, options={}
    input_id = "recipe_picurl"
    input_name = "recipe[picurl]"
    img_id = "rcpPic#{entity_id}"
    link_id = "golink#{entity_id}"
    pic_picker_link = pic_preview_golink page_url, img_url, link_id, img_id, input_id
    pic_preview =
      %Q{<img alt="Image Link is Broken"
              id="#{img_id}"
              src="#{img_url}"
              style="width:100%; height: auto">
         <input type="hidden"
                id="#{input_id}"
                name="#{input_name}"
                rel="jpg,png,gif"
                type="text"
                value="#{img_url}">
        }.html_safe
    content_tag( :div, pic_preview, :class => :pic_preview)+
    content_tag( :div, pic_picker_link, :class => :pic_picker_link)
  end

  # The link to the picture-picking dialog preloads the dialog, extracting picture links from the recipe's page
  def pic_preview_golink page_url, img_url, link_id, img_id, input_id
    queryparams = { picurl: img_url, golinkid: link_id }
    queryparams[:pageurl] = page_url if page_url
    link_to_modal page_url ? "Pick Picture" : "Get Picture from Web",
                    pic_picker_new_path(queryparams),
                    id: link_id,
                    class: "preload pic_picker_golink",
                    data: { inputid: input_id, imageid: img_id }
  end

  def pic_picker_select_list pageurl
    piclist = page_piclist pageurl # Crack the page for its image links
    return "" if piclist.empty?
    thumbNum = 0
    pics = piclist.collect { |url|
        image_tag(url,
                  style: "width:120px; height: auto; margin:10px; display: none;",
                  class: "pic_pickee",
                  id: "thumbnail#{thumbNum += 1}",
                  alt: "No Image Available")
    }.join(' ').html_safe
    %q{<div class="row"><div class="col-md-12">}.html_safe + pics + "</div></div>".html_safe
    # content_tag(:div, pics, id: "masonry-pic-pickees")
  end

  # Declare an image which gets resized to fit upon loading
  # id -- used to define an id attribute for this picture (all fitpics will have class 'fitPic')
  # float_ttl -- indicates how to handle an empty URL
  # selector -- specifies an alternative selector for finding the picture for resizing
  def page_fitPic(picurl, id = "", placeholder_image = "NoPictureOnFile.png")
    idstr = "rcpPic"+id.to_s
    # Allowing for the possibility of a data URI
    begin
      image_tag(picurl || "",
                class: "fitPic",
                id: idstr,
                onload: 'doFitImage(event);',
                alt: "Image Link is Broken",
		data: { fallbackurl: placeholder_image })
    rescue
      image_tag(placeholder_image,
                class: "fitPic",
                id: idstr,
                onload: 'doFitImage(event);',
                alt: "Image Link is Broken")
    end
  end

  # Same protocol, only image will be scaled to 100% of the width of its parent, with adjustable height
  def page_width_pic(picurl, idstr="rcpPic", placeholder_image = "/assets/NoPictureOnFile.png")
    logger.debug "page_width_pic placing #{picurl.blank? ? placeholder_image : picurl.truncate(40)}"
    # Allowing for the possibility of a data URI
    #    if picurl.match(/^data:image/)
    #      %Q{<img alt="Image Link is Broken" class="thumbnail200" id="#{idstr}" src="#{picurl}" >}.html_safe
    #    else
    begin
      image_tag(picurl || "",
                style: "width: 100%; height: auto",
                id: idstr,
                onload: "RP.validate_img(event);",
                alt: "Image Link is Broken",
		data: { fallbackurl: placeholder_image })
    rescue
      image_tag(placeholder_image,
                style: "width: 100%; height: auto",
                id: idstr,
                alt: "Image Link is Broken")
    end
  end

end
