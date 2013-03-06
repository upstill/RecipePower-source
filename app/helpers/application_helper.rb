require "Domain"
require './lib/controller_utils.rb'
module ApplicationHelper
    include ActionView::Helpers::DateHelper
    
    def resource_name
      :user
    end

    def resource
      @resource ||= User.new
    end

    def devise_mapping
      @devise_mapping ||= Devise.mappings[:user]
    end
    
    # The coder is for stripping HTML entities from URIs, recipe titles, etc.
    @@coder = HTMLEntities.new
    
  def decodeHTML(str)
      @@coder.decode str
  end
  
  def encodeHTML(str)
      @@coder.encode str
  end
    
  def link_to_add_fields(name, f, association, *initializers)
    new_object = f.object.send(association).klass.new *initializers
    id = new_object.object_id
    fields = f.fields_for(association, new_object, child_index: id) do |builder|
      render(association.to_s.singularize + "_fields", f: builder)
    end
    link_to(name, '#', class: "add_fields", data: {id: id, fields: fields.gsub("\n", "")}, hidden: true )
  end
  
  def link_to_remove_fields(name, f)
    f.hidden_field(:_destroy) + link_to_function(name, "remove_fields(this)")
  end
  
  def recipe_popup( rcp )
      link_to image_tag("preview.png", title:"Show the recipe in a popup window", class: "preview_button"), rcp.url, target: "_blank", class: "popup", id: "popup#{rcp.id.to_s}"        
  end

  # Declare an image within an adjustable box. The images are downloaded by
  # the browser and their dimensions adjusted under Javascript by the fitImageOnLoad() function.
  # id -- used to define an id attribute for this picture (all fitpics will have class 'fitPic')
  # float_ttl -- indicates how to handle an empty URL
  # selector -- specifies an alternative selector for finding the picture for resizing
  def page_fitPic(picurl, id = "", placeholder_image = "MissingPicture.png", selector=nil)
    logger.debug "page_fitPic placing #{picurl.blank? ? placeholder_image : picurl.truncate(40)}"
    # "fitPic" class gets fit inside pic_box with Javascript and jQuery
    idstr = "rcpPic"+id.to_s
    selector = selector || "##{idstr}"
    if picurl.blank?
      picurl = placeholder_image
    end
    # Allowing for the possibility of a data URI
#    if picurl.match(/^data:image/)
#      %Q{<img alt="Some Image Available" class="thumbnail200" id="#{idstr}" src="#{picurl}" >}.html_safe
#    else
      begin
    	  image_tag(picurl, 
          class: "fitPic",
          id: idstr,
          onload: "fitImageOnLoad('#{selector}')",
          alt: "Some Image Available")
      rescue
    	  image_tag(placeholder_image, 
          class: "fitPic",
          id: idstr,
          onload: "fitImageOnLoad('#{selector}')",
          alt: "Some Image Available")
      end
#    end
  end
  
#  def pic_picker picurl, pageurl, id
#    pic_picker_shell (pic_picker_contents picurl, pageurl, id)
#  end

  # Show an image that will resize to fit an enclosing div, possibly with a link to an editing dialog
  # We'll need the id of the object, and the name of the field containing the picture's url
  def pic_field(obj, attribute, form, editable = true)
    picurl = obj.send(attribute)
    preview = content_tag(
      :div, 
      page_fitPic(picurl, obj.id, "PickPicture.png", "div.recipe_pic_preview img")+
                form.text_field(attribute, rel: "jpg,png,gif", hidden: true),
      class: "recipe_pic_preview"
    )
    picker = editable ?
      content_tag(:div,
            link_to( "Pick Picture", "/", :data=>"recipe_picurl;div.recipe_pic_preview img", :class => "pic_picker_golink")+
            pic_picker_shell(obj), # pic_picker(obj.picurl, obj.url, obj.id), 
            :class=>"recipe_pic_picker"
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
      pageurl = @site.home+@site.sample
      id = @site.id
    end
    piclist = Site.piclist pageurl
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
            class: "fitPic", 
            id: idstr, 
            onclick: "pickImg('input.icon_picker', 'div.preview img', '#{url}')", 
            onload: "fitImageOnLoad('##{idstr}')", 
            alt: "No Image Available"),
          class: "picCell")
      }.join('</td><td>')+
      "</td></tr>"
      piclist = piclist.slice(6..-1) || [] # Returns nil when off the end of the array
    end
    picID = "rcpPic"+id.to_s
    if picrows.empty?
      tblstr = ""
      prompt = "There are no pictures on the page, but you can paste a URL below, then click Okay."
    else
      tblstr = "<br><table>#{picrows}</table>"
      prompt = "Pick one of the thumbnails<br>or type/paste the URL below, then click Okay.".html_safe
    end
    content_tag( :div, 
      page_fitPic( picurl, id, "MissingPicture.png", "div.preview img" ),
      class: "preview" )+
    content_tag( :div, prompt, class: "prompt" )+
    %Q{
        <br class="clear"> 
        <input type="text" class="icon_picker" 
          rel="jpg,png,gif" 
          value="#{picurl}" 
          onchange="previewImg('input.icon_picker', 'div.preview img', '')" />
        <u>Preview</u>
        #{tblstr}       
    }.html_safe      
  end
  
  def recipe_list_element_golink_class recipe
    "rcpListGotag"+@recipe.id.to_s    
  end
  
  def recipe_list_element_class recipe
    "rcpListElmt"+@recipe.id.to_s    
  end
  
  def recipe_grid_element_class recipe
    "rcpGridElmt"+@recipe.id.to_s    
  end
  
  def feed_list_element_class entry
    "feedListElmt"+entry.id.to_s    
  end

  # Return the id of the DOM element giving the time-since-touched for a recipe
  def touch_date_class recipe
    "touchtime#{recipe.id.to_s}"
  end

  # Present the date and time the recipe was last touched by its current user
  def touch_date_elmt recipe
    if params[:controller] == "collection"
      stmt = @seeker.timestamp recipe
    elsif td = recipe.touch_date
      stmt = "Last touched/viewed #{time_ago_in_words td} ago."
    else
      stmt = "Never touched or viewed"
    end
    content_tag :span, stmt, class: touch_date_class(recipe)
  end    
        
  # Create a popup selection list for adding a rating to the tags
  def select_to_add_rating(name, f, association, ratings, inex)
    # Derive 'fields', the information needed by the 'add_rating' javascript
    new_object = Rating.new # f.object.class.reflect_on_association(association).klass.new
    fields = f.fields_for(association, new_object, :child_index => "new_#{association}") do |builder|
      render( "shared/" + association.to_s.singularize + "_fields_" + inex.to_s, :f => builder)
    end
    new_object = {:scale_id=>2}
    fields2 = f.fields_for(association, new_object, :child_index => "new_#{association}") do |builder|
      render( "shared/" + association.to_s.singularize + "_fields_" + inex.to_s, :f => builder)
    end
    # Collect the options from the available ratings, each having
    # value equal to the scale's id, with a title from the scale's name, so 
    # that the javascript function can use it in the rating label(s)
    opcs = Scale.find(:all).collect { |s| 
      # Only allow selection of scales that are unrated thus far
      ratings.index {|r| r.scale_id == s.id } ? "" : "<option value=\"#{s.id}\" title=\"#{s.minlabel} to #{s.maxlabel} \" >#{s.name}</option>"
    }.join('')
    prompt = opcs.empty? ? "No More Ratings to Add" : "Add a Rating"
    opcs = ("<option value=\"0\" >#{prompt}</option>"+opcs).html_safe
    select_tag('Add Rating', 
	    opcs,
	    :prompt => "Pick a Rating to Add",
	    onchange: h("add_rating(this, '#{association}', '#{escape_javascript(fields)}')"))
  end

  def title ttl=nil
    # Any controller can override the default title of controller name
    # ext = (ttl || @Title || (@recipe && @recipe.title) || params[:controller].capitalize)
    #"RecipePower"+(ext.blank? ? " Home" : " | #{ext}")
    "RecipePower"
  end

  def logo(small=false)
    link_to image_tag("RPlogo.png", :alt=>"RecipePower", :id=>"logo_img"+(small ? "_small" : "") ), root_path
  end
  
  def enumerate_strs strs
    case strs.count
    when 0
      ""
    when 1
      strs[0]
    else
      last = strs.pop
      strs.join(', ')+" and " + last
    end
  end
  
  # Helper to interpolate the notifications panel
  def notifications_panel
    %Q{<div class="notifications-panel">#{flash_all}</div>}.html_safe
	end
	
	# Returns a selector-value pair for replacing the notifications panel due to an update event
	def notifications_replacement
	  [ "div.notifications-panel", notifications_panel ]
	end

  # Deploy the links for naming the user and/or signing up/signing in
  def user_status
    userlinks = []
    if user = current_user
       userlinks << link_to(user.handle, users_profile_path) # users_edit_path 
       userlinks << link_to("Sign Out", destroy_user_session_path, :method=>"delete")
       userlinks << navlink("Invite", new_user_invitation_path, (@nav_current==:invite))
    else
       userlinks << link_to_function("Sign In", "recipePowerGetAndRunJSON('authentications/new', 'modal')" )
    end
 	userlinks << navlink("Admin", admin_path) if permitted_to?(:admin, :pages)
 	userlinks.join('&nbsp|&nbsp').html_safe
  end

  def bookmarklet
    imgtag = image_tag("cookmark_button.png", class:"bookmarklet", alt:"Cookmark") 
    if Rails.env.development? || true
      # New bookmarklet
      bmtag = %Q{<a class="bookmarklet" title="Cookmark" href="javascript:(function%20()%20{var%20s%20=%20document.createElement(%27script%27);s.setAttribute(%27language%27,%27javascript%27);s.setAttribute(%27id%27,%20%27recipePower-injector%27);s.setAttribute(%27src%27,%27http://#{current_domain}/recipes/capture.js?recipe[url]=%27+encodeURIComponent(window.location.href)+%27&recipe[title]=%27+encodeURIComponent(document.title)+%27&recipe[rcpref][comment]=%27+encodeURIComponent(%27%27+(window.getSelection?window.getSelection():document.getSelection?document.getSelection():document.selection.createRange().text))+%27&v=6&jump=yes%27);document.body.appendChild(s);}())">}
    else
      # Old bookmarklet
      bmtag = %Q{<a class="bookmarklet" title="Cookmark" href="javascript:void(window.open('http://#{current_domain}/recipes/new?url='+encodeURIComponent(window.location.href)+'&title='+encodeURIComponent(document.title)+'&notes='+encodeURIComponent(''+(window.getSelection?window.getSelection():document.getSelection?document.getSelection():document.selection.createRange().text))+'&v=6&jump=yes',%20'popup',%20'width=600,%20height=300,%20scrollbars,%20resizable'))">}
    end
    (bmtag+imgtag+"</a>").html_safe
  end

  def navlink(label, link, is_current=false)
    if is_current
      "<span class='nav_link_strong'><i>#{label}</i></span>"
    else
      link_to label, link, class: "nav_link"
    end
  end

  # Return the set of navigation links for the header
  def header_navlinks
    navlinks = []
    navlinks.push(navlink "Cookmarks", collection_path, (@nav_current==:cookmarks)) 
    navlinks.push(link_to_dialog "Add a Cookmark", new_recipe_path, "modal", "floating" )
    # navlinks.push(link_to_function("Add a Cookmark", "rcpAdd()" )) # navlink "Add a Cookmark", new_recipe_path, (@nav_current==:addcookmark)) 
    navlinks.join('&nbsp|&nbsp').html_safe
  end
    
  def footer_navlinks
  	navlinks = []
  	navlinks << navlink("About", about_path, (@nav_current==:about)) 
  	navlinks << navlink("Contact", contact_path, (@nav_current==:contact)) 
  	navlinks << navlink("Home", home_path, (@nav_current==:home)) 
  	navlinks << navlink("FAQ", "/FAQ", (@nav_current==:FAQ)) 
  	# navlinks << feedback_link("Feedback")
  	navlinks.join('  |  ').html_safe
  end
  
=begin
  def show_errors(errors)
    result = ""
    if errors.any?
      result << "<div id=\"error_explanation\"><h2>\n"
      result << "Sorry, but "
      result << (errors.count > 1 ? "#{errors.count.to_s} errors are" : "an error is")
      result << " keeping that from happening:</h2>\n"
      result << "<ul>"
      errors.full_messages.each do |msg|
          result << "<li>#{msg}</li>\n"
      end
      result << "</ul>\n</div>"
    end
    result.html_safe
  end
=end

  def debug_dump(params)
      "<div id=\"debug\">#{debug(params)}</div>".html_safe
	end
	
	def button_to_dialog(label, path, how="modal", where="floating", options={})
	  options[:class] = "btn btn-mini"
	  link_to_dialog label, path, how, where, options
	end
	
	# Embed a link to javascript for running a dialog by reference to a URL
	def link_to_dialog(label, path, how="modal", where="floating", options={})
  	link_to_function label, "recipePowerGetAndRunJSON('#{path}', '#{how}', '#{where}');", options
  end
	
	def button_to_modal(label, path, how="modal", where="floating", options={})
	  options[:class] = "btn btn-mini"
	  link_to_modal label, path, options
	end
	
	# Embed a link to javascript for running a dialog by reference to a URL
	def link_to_modal(label, path, options={})
  	link_to_function label, "RP.dialog.get_and_go('#{path}');", options
  end
  
  def link_to_redirect(label, url, options={} )
  	link_to_function label, "redirect_to('#{url}');", options
  end
	
	def globstring(hsh)
    hsh.keys.each.collect { |key| 
      key.to_s+": ["+(hsh[key] ? hsh[key].to_s : "nil")+"]"
    }.join(' ')
  end
  
  # Declare a dialog div with content to be supplied later using the template
  def dialogDiv( which, ttl=nil, area="floating", template="")
    logger.debug "dialogHeader for "+globstring({dialog: which, area: area, layout: @layout, ttl: ttl})
    classname = which.to_s
    ttlspec = ttl ? (" title=\"#{ttl}\"") : ""
    content_tag(:div, 
        "",
        class: classname+" dialog hide "+area, 
        id: "recipePowerDialog", 
        "data-template" => template)
  end
  
  def modal_dialog( which, ttl=nil, options={}, &block )
    options[:modal] = true if options[:modal].nil?
    dlg = with_output_buffer &block
    (dialogHeader(which, ttl, options)+
     dlg+
     dialogFooter).html_safe
  end
  
  def modal_body(&block)
    bd = with_output_buffer &block
    content_tag :div, flash_all + bd, class: "modal-body"
  end
  
  def modal_footer(&block)
    ft = with_output_buffer &block
    content_tag :div, ft, class: "modal-footer"
  end
  
  # Place the header for a dialog, including setting its Onload function.
  # Currently handled this way (e.g., symbols that have been supported)
  #   :edit_recipe
  #   :captureRecipe
  #   :new_recipe (nee newRecipe)
  #   :sign_in
  def dialogHeader( which, ttl=nil, options={})
    # Render for a floating dialog unless an area is asserted OR we're rendering for the page
    area = options[:area] || "floating" # (@partial ? "floating" : "page")
    hide = options[:show] ? "" : "hide"
    # class 'modal' is for use by Bootstrap modal; it's obviated when rendering to a page (though we can force
    # it for pre-rendered dialogs by asserting the :modal option)
    modal = options[:modal] ? "modal-pending" : ""
    logger.debug "dialogHeader for "+globstring({dialog: which, area: area, ttl: ttl})
    # Assert a page title if given
    ttlspec = ttl ? %Q{ title="#{ttl}"} : ""
        
    hdr = 
      %Q{<div id="recipePowerDialog" class="#{modal} dialog #{which.to_s} #{area}" #{ttlspec}>}+
      (options[:modal] ? 
        %Q{
          <div class="modal-header">
            <h3>#{ttl}</h3>
          </div>} : 
        %q{
          <div class="recipePowerCancelDiv">
            <a href="#" id="recipePowerCancelBtn" onclick="cancelDialog; return false;" style="text-decoration: none;">X</a>
          </div>})+
      %q{<div class="notifications-panel"></div>}
    hdr.html_safe
  end

  def dialogFooter()
    "</div><br class='clear'>".html_safe
  end

   def pagination_link (text, pagenum, url)
     # "<span value='#{p.to_s}' class='pageclickr'>#{p.to_s}</span>"
     # We install the actual pagination handler in RPquery.js::queryTabOnLoad
     link_to_function text.html_safe, ";", class: "pageclickr", value: pagenum.to_s, :"data-url" => url
   end

   def pagination_links(npages, cur_page, url="collection/query" )
     if npages > 1
       maxlinks = 11
       halfwidth = (maxlinks-6)/2

       cur_page = npages if cur_page > npages
       blockleft = cur_page-1-halfwidth
       blockright = cur_page-1 + halfwidth
       shift = (3-blockleft)
       if(shift > 0)
           blockleft = blockleft + shift
           blockright = blockright + shift
       end
       shift = blockright - (npages-4)
       if(shift > 0)
           blockright = blockright - shift
           blockleft = blockleft - shift
           blockleft = 3 if(blockleft < 3)
       end

       blockleft = 0 unless blockleft > 3
       blockright = npages-1 unless blockright < (npages-4)
       pages = (blockleft..blockright).map { |i| i+1 }
       pages = [1,2,nil] + pages if(blockleft > 0)
       pages << [ nil, (npages-1), npages] if(blockright < (npages-1))
       links = pages.flatten.map do |p| 
           case p
           when nil
               "<span class=\"disabled\">...</span>"
           when cur_page
               "<span class=\"current\">#{p.to_s}</span>"
           else
               pagination_link p.to_s, p, url
           end
       end
       if cur_page > 1
           links.unshift pagination_link("&#8592; Previous", cur_page-1, url)
           links.unshift pagination_link("First ", 1, url)
       else
           links.unshift "<span class=\"disabled previous_page\">&#8592; Previous</span>"
           links.unshift "<span class=\"disabled previous_page\">First </span>"
       end
       if cur_page < npages
           links << pagination_link("Next &#8594;", cur_page+1, url)
           links << pagination_link(" Last", npages, url)
       else
           links << "<span class=\"disabled next_page\">Next &#8594;</span>"
           links << "<span class=\"disabled next_page\"> Last</span>"
       end
       links.join(' ').html_safe
     end
   end
   
  # Augments error display for record attributes (a la simple_form) with base-level errors
  def display_base_errors resource
    flash_one :error, base_errors(resource)
  end
  
  # Report the current errors on a record in a nice alert div, suitable for interpolation on the page
  def errors_helper obj, attribute=nil
    unless obj.errors.empty?
      flash_one :error, error_notification(obj, attribute)
    end
  end

  def flash_one level, message, for_bootstrap=true
    return "".html_safe if message.blank?
    if for_bootstrap
      bootstrap_class =
      case level
      when :success
        "alert-success"
      when :error
        "alert-error"
      when :alert
        "alert-block"
      when :notice
        "alert-info"
      else
        flash_type.to_s
      end
       # This message may have been cleared earlier...
      html = <<-HTML
        <div class="alert #{bootstrap_class} alert_block fade in">
          <button class="close" data-dismiss="alert">&#215;</button>
          #{message}
        </div>
        HTML
    else
      html = %Q{<div class="generic_alert" style="display: block; background-color:#fcf8e3; border: 1px solid #f9f6dc; padding:3px; border:3px;">#{message}</div>}
    end
    flash.delete(level)
    html.html_safe
  end
  
  def flash_all for_bootstrap=true
    flash.collect { |type, message| flash_one type, message, for_bootstrap }.join.html_safe
  end
end
