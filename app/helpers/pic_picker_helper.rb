module PicPickerHelper

  def pic_preview_widget page_url, pic_url, entity_id, options={}
    pic_picker_link =
    link_to_preload "Pick Picture",
                    %Q{/pic_picker/new?picurl=#{pic_url}&pageurl=#{page_url}&entity_id=#{entity_id}}, # %Q{/recipes/#{entity_id}/edit?pic_picker=true},
                    class: "hide pic_picker_golink",
                    data: { vals: "recipe_picurl;div.pic_preview img" }
    pic_preview =
      %Q{<img alt="Some Image Available"
              id="rcpPic#{entity_id}"
              src="#{pic_url}"
              style="width:100%; height: auto">
         <input type="hidden"
                id="recipe_picurl"
                name="recipe[picurl]"
                rel="jpg,png,gif"
                type="text"
                value="#{pic_url}">
        }.html_safe
    content_tag( :div, pic_preview, :class => :pic_preview)+
    content_tag( :div, pic_picker_link, :class => :pic_picker_link)
  end

  # Show an image that will resize to fit an enclosing div, possibly with a link to an editing dialog
  # We'll need the id of the object, and the name of the field containing the picture's url
  def pic_field(obj, attribute, form, is_local = true, fallback_img="NoPictureOnFile.png")
    picurl = obj.send(attribute)
    pic_area = is_local ?
        page_width_pic(picurl, obj.id, fallback_img, "div.pic_preview img") :
        page_fitPic(picurl, obj.id)
    preview = content_tag(
        :div,
        pic_area+form.text_field(attribute, rel: "jpg,png,gif", hidden: true, class: "hidden_text" ),
        class: "pic_preview"
    )
    picker = is_local ?
        content_tag(:div,
                    link_to( "Pick Picture", "/", :data=>{ vals: "recipe_picurl;div.pic_preview img" }, :class => "pic_picker_golink hide")+
                        pic_picker_shell(obj), # pic_picker(obj.picurl, obj.url, obj.id),
                    :class=>"pic_picker_link"
        ) # Declare the picture-picking dialog
    : ""
    content_tag :div, preview + picker, class: "edit_recipe_field pic"
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
                 page_width_pic( picurl, id, "NoPictureOnFile.png", "div.preview img" ),
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
  def page_width_pic(picurl, id = "", placeholder_image = "NoPictureOnFile.png", selector=nil)
    logger.debug "page_width_pic placing #{picurl.blank? ? placeholder_image : picurl.truncate(40)}"
    idstr = "rcpPic"+id.to_s
    selector ||= "##{idstr}"
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
