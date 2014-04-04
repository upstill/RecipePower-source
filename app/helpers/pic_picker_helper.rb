module PicPickerHelper

  def pic_preview_widget page_url, img_url, entity_id, options={}
    input_id = "recipe_picurl"
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
                name="recipe[picurl]"
                rel="jpg,png,gif"
                type="text"
                value="#{img_url}>
        }.html_safe
    content_tag( :div, pic_preview, :class => :pic_preview)+
    content_tag( :div, pic_picker_link, :class => :pic_picker_link)
  end

  # The link to the picture-picking dialog preloads
  def pic_preview_golink page_url, img_url, link_id, img_id, input_id
    # img_url =  URI::encode img_url
    # page_url =  URI::encode page_url
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

  # Show an image that will resize to fit an enclosing div, possibly with a link to an editing dialog
  # We'll need the id of the object, and the name of the field containing the picture's url
  def pic_field(obj, attribute, form, is_local = true, fallback_img="NoPictureOnFile.png")
    objj = form.object
    picurl = obj.send(attribute)
    input_id = obj.class.to_s.downcase + "_" + attribute # "recipe_picurl"
    img_id = "rcpPic#{obj.id}"
    link_id = "golink#{obj.id}"
    pic_area = is_local ?
        page_width_pic(picurl, img_id, fallback_img) :
        page_fitPic(picurl, obj.id)
    preview = content_tag :div,
                          pic_area+form.text_field(attribute, rel: "jpg,png,gif", hidden: true, class: "hidden_text"),
                          class: "pic_preview"
    preview << pic_preview_golink(obj.url, picurl, link_id, img_id, input_id) if is_local
    content_tag :div, preview, class: "edit_recipe_field pic"
  end

  def page_pic_select_list pageurl
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

  # Declare the (empty) contents of the pic_picker dialog, embedding a url for the client to request the actual dialog data
  def pic_picker_shell obj, contents=""
    controller = params[:controller]
    content_tag :div,
                contents,
                class: "pic_picker",
                style: "display:none;",
                "data-url" => "/#{controller}/#{obj.id}/edit?pic_picker=true"
  end

  # Build a picture-selection dialog with the default url, url for a page containing candidate images, id, and name of input field to set
  def pic_picker_contents
    if @recipe
      picurl = @recipe.picurl
      pageurl = @recipe.url
      id = @recipe.id
    else
      picurl = @site.logo
      pageurl = @site.sampleURL
      id = @site.id
    end
    piclist = page_piclist pageurl
    pictab = []
    # divide piclist into rows of four pics apiece
    picrows = ""
    thumbNum = 0
    # Divide the piclist of URLs into rows of four, accumulating HTML for each row
    until piclist.empty?
      picrows << "<tr><td>"+
          piclist.slice(0..5).collect{ |url|
            idstr = "thumbnail"+(thumbNum = thumbNum+1).to_s
            content_tag( :div,
                         image_tag(url,
                                   style: "width:100%; height: auto;",
                                   id: idstr,
                                   onclick: "RP.pic_picker.make_selection('#{url}')", class: "fitPic", onload: "doFitImage(event);",
                                   alt: "No Image Available"),
                         class: "picCell")
          }.join('</td><td>')+
          "</td></tr>"
      piclist = piclist.slice(6..-1) || [] # Returns nil when off the end of the array
    end
    picID = "rcpPic"+id.to_s
    if picrows.empty?
      tblstr = ""
      prompt = "There are no pictures on the recipe's page, but you can paste a URL into the text box below."
    else
      tblstr = "<br><table>#{picrows}</table>"
      prompt = "Pick one of the thumbnails, then click Okay.<br><br>Or, type or paste the URL of an image.".html_safe
    end
    content_tag( :div,
                 page_width_pic( picurl, picID ),
                 class: "preview" )+
        content_tag( :div, prompt, class: "prompt" )+
        ( %Q{<br class="clear">
        <input type="text" class="icon_picker"
        rel="jpg,png,gif"
        value="#{picurl}" />&nbsp;}+
            link_to("Preview", "#", class: "image_preview_button" )+
            tblstr
        ).html_safe
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
