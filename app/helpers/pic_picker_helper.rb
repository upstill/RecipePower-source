module PicPickerHelper

  # Show an image that will resize to fit an enclosing div, possibly with a link to an editing dialog
  # We'll need the id of the object, and the name of the field containing the picture's url
  def pic_field(form, pic_attribute, page_attribute, fallback_img="NoPictureOnFile.png")
    obj = form.object
    picurl = obj.send(pic_attribute)
    input_id = obj.class.to_s.downcase + "_" + pic_attribute.to_s
    img_id = "rcpPic#{obj.id}"
    link_id = "golink#{obj.id}"
    pic_area = page_width_pic picurl, img_id, fallback_img
    preview = content_tag :div,
                          pic_area+form.text_field(pic_attribute, rel: "jpg,png,gif", hidden: true, class: "hidden_text"),
                          class: "pic_preview"
    preview << pic_preview_golink(obj.send(page_attribute), picurl, link_id, img_id, input_id) if page_attribute
    content_tag :div, preview, class: "edit_recipe_field pic"
  end

  # Bare-metal version of the pic preview widget, for use in a template file
  def pic_preview_widget page_url, img_url, entity_id, options={}
    input_id = "recipe_picurl"
    input_name = "recipe[picurl]"
    img_id = "rcpPic#{entity_id}"
    link_id = "golink#{entity_id}"
    pic_picker_link = pic_preview_golink page_url, img_url, link_id, img_id, input_id
    pic_preview =
      %Q{<img alt="Some Image Available"
              id="#{img_id}"
              src="#{img_url}"
              style="width:100%; height: auto">
         <input type="hidden"
                id="#{input_id}"
                name="#{input_name}"
                rel="jpg,png,gif"
                type="text"
                value="#{img_url}>
        }.html_safe
    content_tag( :div, pic_preview, :class => :pic_preview)+
    content_tag( :div, pic_picker_link, :class => :pic_picker_link)
  end

  # The link to the picture-picking dialog preloads the dialog, extracting picture links from the recipe's page
  def pic_preview_golink page_url, img_url, link_id, img_id, input_id
    link_to_preload "Pick Picture",
                    %Q{/pic_picker/new?picurl=#{img_url}&pageurl=#{page_url}&golinkid=#{link_id}}, # %Q{/recipes/#{entity_id}/edit?pic_picker=true},
                    id: link_id,
                    class: "hide pic_picker_golink",
                    data: {
                        img_id: img_id,
                        input_id: input_id,
                        preload: {
                            request: "/pic_picker/new",
                            querydata: {
                                picurl: img_url,
                                pageurl: page_url,
                                golinkid: link_id
                            }
                        }
                    }
  end

  def pic_picker_select_list pageurl
    piclist = page_piclist pageurl # Crack the page for its image links
    return "" if piclist.empty?
    # divide piclist into rows of six pics apiece
    picrows, thumbNum = "", 0
    # Divide the piclist of URLs into rows of four, accumulating HTML for each row
    until piclist.empty?
      picrow = piclist.slice!(0..11).collect { |url|
        content_tag(:div,
                    image_tag(url,
                              style: "width:100%; height: auto;",
                              id: "thumbnail#{thumbNum += 1}",
                              onclick: "RP.pic_picker.make_selection('#{url}')", # class: "fitPic", onload: "doFitImage(event);",
                              alt: "No Image Available"),
                    class: "col-xs-6 col-sm-4 col-md-3 col-lg-2",
                    style: "margin-bottom: 10px")
      }.join(' ')
      picrows << content_tag(:div, picrow.html_safe, class: "row")
    end
    picrows
  end

  # Declare an image which gets resized to fit upon loading
  # id -- used to define an id attribute for this picture (all fitpics will have class 'fitPic')
  # float_ttl -- indicates how to handle an empty URL
  # selector -- specifies an alternative selector for finding the picture for resizing
  def page_fitPic(picurl, id = "", placeholder_image = "NoPictureOnFile.png")
    idstr = "rcpPic"+id.to_s
    picurl = "NoPictureOnFile.png" if picurl.blank?
    # Allowing for the possibility of a data URI
    begin
      image_tag(picurl,
                class: "fitPic",
                id: idstr,
                onload: 'doFitImage(event);',
                alt: "Some Image Available")
    rescue
      image_tag(placeholder_image,
                class: "fitPic",
                id: idstr,
                onload: 'doFitImage(event);',
                alt: "Some Image Available")
    end
  end

  # Same protocol, only image will be scaled to 100% of the width of its parent, with adjustable height
  def page_width_pic(picurl, idstr="rcpPic", placeholder_image = "NoPictureOnFile.png")
    logger.debug "page_width_pic placing #{picurl.blank? ? placeholder_image : picurl.truncate(40)}"
    picurl = placeholder_image if picurl.blank?
    # Allowing for the possibility of a data URI
    #    if picurl.match(/^data:image/)
    #      %Q{<img alt="Some Image Available" class="thumbnail200" id="#{idstr}" src="#{picurl}" >}.html_safe
    #    else
    begin
      image_tag(picurl,
                style: "width: 100%; height: auto",
                id: idstr,
                alt: "Some Image Available")
    rescue
      image_tag(placeholder_image,
                style: "width: 100%; height: auto",
                id: idstr,
                alt: "Some Image Available")
    end
  end

end
