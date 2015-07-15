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
  def pic_field form, pic_attribute, page_attribute=nil, options={}
    if page_attribute.is_a? Hash
      page_attribute, options = nil, page_attribute
    end
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

    # pic_area = page_width_pic obj.imgdata(true), img_id
    pic_area = image_with_error_recovery obj.imgdata(true), id: img_id, leave_blank: true
    field_options = {
        rel: "jpg,png,gif",
        class: "hidden_text",
        onchange: ("RP.submit.enclosing_form" if options[:submit_on_change])
    }
    preview = content_tag :div,
                          pic_area+form.hidden_field(pic_attribute, field_options.compact),
                          class: "pic_preview"

    golink_attribs =
        {
            pageurl: pageurl,
            picurl: picurl,
            golinkid: link_id,
            imageid: img_id,
            inputid: input_id,
            picrefid: obj.picrefid,
            fallback_img: obj.fallback_imgdata
        }.compact

    preview << content_tag(:div,
                           pic_preview_golink(golink_attribs),
                           class: "pic_picker_link") unless options[:nopicker]
    preview
  end

  # Bare-metal version of the pic preview widget, for use in a template file
  def pic_preview_widget templateer, options={}
    img_url_value = templateer.picuri
    input_id = pic_preview_input_id(templateer, :picurl) # "recipe_picurl"
    img_id = pic_preview_img_id(templateer)

    pic_preview =
      image_with_error_recovery(templateer.imgdata(true), id: img_id, style: "width:100%; height: auto") +
      hidden_field_tag( templateer.field_name(:picurl),
                        img_url_value,
                        id: input_id,
                        rel: "jpg,png,gif",
                        type: "text"
      )

    # The golink fires off a request for the pic picker, so it needs a few parameters
    pic_preview_attribs = {
        pageurl: (templateer.url rescue nil),
        picurl: img_url_value,
        golinkid: "golink#{templateer.id}",
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

end
