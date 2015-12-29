module PicPickerHelper

  def pic_preview_img_id decorator
    "rcpPic#{decorator.id}"
  end

  def pic_preview_input_id decorator
    decorator.element_id decorator.picable_attribute
  end

  # Show an image that will resize to fit an enclosing div, possibly with a link to an editing dialog
  # We'll need the id of the object, and the name of the field containing the picture's url
  def pic_field form, options={}
    # We work with a decorator, whether provided or not
    decorator = options[:decorator] || form.object
    # The form may be working with an object, not its decorator
    decorator = decorator.decorate unless decorator.is_a?(Draper::Decorator)

    pic_area = image_with_error_recovery decorator,
                                         id: pic_preview_img_id(decorator),
                                         class: 'fixed-width',
                                         fallback_img: options[:fallback_img] || true
    field_options = {
        rel: "jpg,png,gif",
        class: "hidden_text",
        onchange: ("RP.submit.enclosing_form" if options[:submit_on_change])
    }
    preview = content_tag :div,
                          pic_area+form.hidden_field(decorator.picable_attribute, field_options.compact),
                          class: "pic_preview"
    preview << content_tag(:div,
                           pic_picker_go_button(decorator, options[:fallback_img]),
                           class: "pic_picker_link") unless options[:nopicker]
    preview
  end

  # Bare-metal version of the pic preview widget, for use in a template file
  def pic_preview_widget decorator, options={}
    pic_preview =
      image_with_error_recovery(decorator.object,
                                id: pic_preview_img_id(decorator),
                                fill_mode: 'fixed-width') +
      hidden_field_tag( decorator.field_name(:picurl),
                        decorator.picuri,
                        id: pic_preview_input_id(decorator),
                        rel: "jpg,png,gif",
                        type: "text"
      )

    content_tag(:div, pic_preview, :class => :pic_preview)+
    content_tag(:div, pic_picker_go_button(decorator), :class => :pic_picker_link)
  end

  def pic_picker_golinkid decorator
    "golink#{decorator.id}"
  end

  # The link to the picture-picking dialog preloads the dialog, extracting picture links from the recipe's page
  def pic_picker_go_button decorator, picker_fallback_img=nil
    golink = polymorphic_path [:editpic, decorator.object],
                              golinkid: pic_picker_golinkid(decorator),
                              fallback_img: (picker_fallback_img || "NoPictureOnFile.png")
    button_to_submit decorator.pageurl ? "Pick Picture..." : "Get Picture from Web...",
                     golink,
                     "default",
                     "small",
                     id: pic_picker_golinkid(decorator),
                     preload: true,
                     :mode => :modal,
                     class: "pic_picker_golink",
                     data: {
                         inputid: pic_preview_input_id(decorator),
                         imageid: pic_preview_img_id(decorator)
                     }
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
