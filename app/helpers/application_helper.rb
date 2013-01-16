require "Domain"
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
  
  def forgot_password_link
    link_to_function "Forgot Password", %Q{recipePowerGetAndRunJSON('#{new_user_password_path}', 'modal')}
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
    logger.debug "page_fitPic placing #{picurl.blank? ? placeholder_image : picurl}"
    # "fitPic" class gets fit inside pic_box with Javascript and jQuery
    idstr = "rcpPic"+id.to_s
    selector = selector || "##{idstr}"
    if picurl.blank?
      picurl = placeholder_image
    end
    # Allowing for the possibility of a data URI
    if picurl.match(/^data:image/)
      %Q{<img alt="Some Image Available" class="fitPic" id="#{idstr}" onload="fitImageOnLoad('#{selector}')" src="#{picurl}">}.html_safe
    else
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
    end
  end
  
#  def pic_picker picurl, pageurl, id
#    pic_picker_shell (pic_picker_contents picurl, pageurl, id)
#  end
  
  # Declare the (empty) contents of the pic_picker dialog, embedding a url for later requesting the actual dialog data
  def pic_picker_shell contents=""
    content_tag :div, 
      contents, 
      class: "pic_picker",
      style: "display:none;",
      "data-url" => @recipe ? "recipes/#{@recipe.id}/edit?pic_picker=true" : ""
  end
  
  # Build a picture-selection dialog with the default url, url for a page containing candidate images, id, and name of input field to set
  def pic_picker_contents picurl, pageurl, id
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

  # Return the id of the DOM element giving the time-since-touched for a recipe
  def touch_date_class recipe
    "touchtime#{recipe.id.to_s}"
  end

  # Present the date and time the recipe was last touched by its current user
  def touch_date_elmt recipe
    if params[:controller] == "collection"
      stmt = @collection.timestamp recipe
    else
      stmt = "Last viewed #{time_ago_in_words recipe.touch_date} ago."
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
  
  def flash_helper
      f_names = [:notice, :warning, :message]
      fl = ''
      for name in f_names
        if flash[name]
          fl = fl + "<div class=\"notice\">#{flash[name]}</div>"
        end
      flash[name] = nil;
    end
    return fl.html_safe
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
      
  # Turn the last comma in a comma-separated list into ' and'
  def englishize_list(list)
    set = list.split ', '
    if(set.length > 1)
      ending = " and " + set.pop
      list = set.join(', ') + ending
    end
    list
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
    navlinks.push(navlink "Cookmarks", rcpqueries_path, (@nav_current==:cookmarks)) 
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
  
  def debug_dump(params)
      "<div id=\"debug\">#{debug(params)}</div>".html_safe
	end
	
	# Embed a link to javascript for running a dialog by reference to a URL
	def link_to_dialog(label, path, how, where, *options)
  	link_to_function label, "recipePowerGetAndRunJSON('#{path}', '#{how}', '#{where}');", *options
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
    flash_helper() +
    content_tag(:div, 
        "",
        class: classname+" dialog "+area, 
        id: "recipePowerDialog", 
        "data-template" => template)
  end
  
  # Place the header for a dialog, including setting its Onload function.
  # Currently handled this way (e.g., symbols that have been supported)
  #   :edit_recipe
  #   :captureRecipe
  #   :new_recipe (nee newRecipe)
  #   :sign_in
  def dialogHeader( which, ttl=nil, area="floating")
    logger.debug "dialogHeader for "+globstring({dialog: which, area: area, layout: @layout, ttl: ttl})
    classname = which.to_s
    ttlspec = ttl ? (" title=\"#{ttl}\"") : ""
    flash_helper() +
    %Q{<div id="recipePowerDialog" class="#{classname} dialog #{area}" #{ttlspec}>}.html_safe +
    ((@layout && @layout=="injector") ? 
      content_tag(:div, 
        link_to_function("X", "cancelDialog", style:"text-decoration: none;", id: "recipePowerCancelBtn"),
        id: "recipePowerCancelDiv")
    : "")
  end

  def dialogFooter()
    "</div><br class='clear'>".html_safe
  end
end
