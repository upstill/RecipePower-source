module PicPickerHelper

  def pic_preview_img_id templateer
    "rcpPic#{templateer.id}"
  end

  def pic_preview_input_id obj, fieldname
    if obj.is_a? Templateer
      obj.element_id(fieldname)
    else
      ((obj.is_a? Draper::Decorator) ? obj.object : obj).class.to_s.downcase + "_" + fieldname.to_s
    end
  end

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
    input_id = pic_preview_input_id(obj, pic_attribute)
    img_id = pic_preview_img_id(obj)
    link_id = "golink#{obj.id}"

    picdata = obj.imgdata || options[:fallback_img] || obj.imgdata(true)
    pic_area = page_width_pic picdata, img_id, options[:fallback_img]
    preview = content_tag :div,
                          pic_area+form.hidden_field(pic_attribute, rel: "jpg,png,gif", class: "hidden_text"),
                          class: "pic_preview"

    golink_attribs =
        options.slice(:fallback_img).
        merge(pageurl: pageurl,
              picurl: picurl,
              golinkid: link_id,
              imageid: img_id,
              inputid: input_id,
              picrefid: obj.picrefid
            ).compact

    preview << content_tag(:div,
                           pic_preview_golink(golink_attribs),
                           class: "pic_picker_link") unless options[:nopicker]
    preview
  end

  # Bare-metal version of the pic preview widget, for use in a template file
  def pic_preview_widget templateer, options={}
    page_url = templateer.url rescue nil
    img_url_display = templateer.imgdata :card # Include explanatory card
    img_url_value = templateer.picuri
    entity_id = templateer.id
    input_id = pic_preview_input_id(templateer, :picurl) # "recipe_picurl"
    input_name = templateer.field_name(:picurl) # "recipe[picurl]"
    img_id = pic_preview_img_id(templateer)
    link_id = "golink#{entity_id}"
    pic_preview =
        %Q{<img alt="Image Link is Broken"
              id="#{img_id}"
              src="#{img_url_display}"
              style="width:100%; height: auto">
         <input type="hidden"
                id="#{input_id}"
                name="#{input_name}"
                rel="jpg,png,gif"
                type="text"
                value="#{img_url_value}">
        }.html_safe

    # The golink fires off a request for the pic picker, so it needs a fair few parameters
    pic_preview_attribs = {
        pageurl: page_url,
        picurl: img_url_value,
        golinkid: link_id,
        imageid: img_id,
        inputid: input_id,
        picrefid: templateer.picrefid
    }.compact

    content_tag(:div, pic_preview, :class => :pic_preview)+
        content_tag(:div, pic_preview_golink(pic_preview_attribs), :class => :pic_picker_link)
  end

  # The link to the picture-picking dialog preloads the dialog, extracting picture links from the recipe's page
  def pic_preview_golink attribs
    button_to_submit attribs[:pageurl] ? "Pick Picture..." : "Get Picture from Web...",
                    pic_picker_new_path(attribs.slice :picurl, :golinkid, :pageurl, :picrefid, :fallback_img),
                    "default",
                    "small",
                    id: attribs[:golinkid],
                    preload: true,
                    :mode => :modal,
                    class: "pic_picker_golink",
                    data: attribs.slice(:inputid, :imageid)
  end

  def pic_picker_select_list pageurl
    piclist = page_piclist pageurl # Crack the page for its image links
    return "" if piclist.empty?
    thumbNum = 0
    pics = piclist.collect { |url|
        image_with_error_recovery(url,
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
  def page_fitPic(picurl, id = "")
    image_with_error_recovery(picurl || "",
                              class: "fitPic",
                              id: "rcpPic"+id.to_s,
                              onload: 'doFitImage(event);',
                              alt: "Image Link is Broken")
  end

  # Same protocol, only image will be scaled to 100% of the width of its parent, with adjustable height
  def page_width_pic(picurl, idstr="rcpPic", report_bad_image = false)
    data = report_bad_image ? { fallbackurl: "/assets/BadPicURL.png" } : {}
    image_with_error_recovery(picurl || "",
                              style: "width: 100%; height: auto",
                              id: idstr,
                              # onload: "RP.validate_img(event);",
                              alt: "Image Link is Broken",
                              data: data)
  end

end
