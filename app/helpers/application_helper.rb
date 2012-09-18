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
  def page_fitPic(picurl, id, float_ttl = true, selector=nil)
    # "fitPic" class gets fit inside pic_box with Javascript and jQuery
    idstr = "rcpPic"+id.to_s
    selector = selector || "##{idstr}"
	if picurl.blank? && float_ttl
	    %Q{<div class="centerfloat" id="#{idstr}">No Image Available</div>}.html_safe
	else
	    %Q{<img src="#{picurl}" class="fitPic" id="#{idstr}" onload="fitImageOnLoad('#{selector}')" alt="No Image Available">}.html_safe
	end
  end
  
  # Build a picture-selection dialog with the default url, url for a page containing candidate images, id, and name of input field to set
  def pic_picker picurl, pageurl, id
    piclist = Site.piclist pageurl
    pictab = []
    # divide piclist into rows of four pics apiece
    picrows = ""
    thumbNum = 0
    # Divide the piclist of URLs into rows of four, accumulating HTML for each row
    until piclist.empty?
        picrows <<  "<tr><td>"+
                    piclist.slice(0..5).collect{ |url| 
                      idstr = "thumbnail"+(thumbNum = thumbNum+1).to_s
                      "<div class = \"picCell\">"+
            	    image_tag(url, class: "fitPic", id: idstr, onclick: "pickImg('input.icon_picker', 'div.preview img', '#{url}')", onload: "fitImageOnLoad('##{idstr}')", alt: "No Image Available")+
            	  "</div>"
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
        prompt = "Pick one of the thumbnails<br>or type/paste the URL below, then click Okay."
    end
    %Q{
        <div class="iconpicker" style="display:none;" >
          <div class="preview">                                     
            #{page_fitPic picurl, id, false, "div.preview img"}  
          </div> 
          <p class="airy">#{prompt}</p>                                                 
          <br class="clear"> 
          <input type="text" class="icon_picker" 
                    rel="jpg,png,gif" 
                    value="#{picurl}" 
                    onchange="previewImg('input.icon_picker', 'div.preview img', '')" />
          <u>Preview</u>
          #{tblstr}       
        </div>                                      
      }.html_safe      
  end
  
  def recipe_list_element_golink_class recipe
    "rcpListGotag"+@recipe.id.to_s    
  end
  
=begin
  def recipe_list_element_golink recipe
	if permitted_to? :update, @recipe
      ("<span class='#{recipe_list_element_golink_class @recipe}'>" + 
      if @recipe.users.exists?(@recipe.current_user)
 	    link_to "Edit Tags", edit_recipe_path(@recipe)
 	  else 
 	    link_to_function "Grab This Cookmark!", "rcpCollect(#{@recipe.id.to_s})"
 	  end + 
 	  "</span>").html_safe
    end
  end      
=end
  
    def recipe_list_element_class recipe
        "rcpListElmt"+@recipe.id.to_s    
    end
      
    # Return the id of the DOM element giving the time-since-touched for a recipe
    def touch_date_class recipe
        "touchtime#{recipe.id.to_s}"
    end

    # Present the date and time the recipe was last touched by its current user
    def touch_date_elmt recipe
        if touched = Touch.touch_date(recipe.id, recipe.current_user)
            %Q{
              <span class="#{touch_date_class(recipe)}">Last viewed #{time_ago_in_words(touched)} ago.</span>
            }.html_safe
        end
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
    ext = (ttl || @Title || (@recipe && @recipe.title) || params[:controller].capitalize)
    "RecipePower"+(ext.blank? ? " Home" : " | #{ext}")
  end

  def logo
    link_to image_tag("RPlogo.png", :alt=>"RecipePower", :id=>"logo_img" ), root_path
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
       userlinks << link_to_function("Sign In", "applyForInteraction('authentications/new')" )
    end
 	userlinks << navlink("Admin", admin_path) if permitted_to?(:admin, :pages)
 	userlinks.join('&nbsp|&nbsp').html_safe
  end

  def bookmarklet
      imgtag = image_tag("Small_Icon.png", :alt=>"Cookmark", :class=>"logo_icon", width: "32px", height: "24px")
      bmtag = %q{<a class="bookmarklet" title="Cookmark" href="javascript:void(window.open('http://www.recipepower.com/recipes/new?url='+encodeURIComponent(window.location.href)+'&title='+encodeURIComponent(document.title)+'&notes='+encodeURIComponent(''+(window.getSelection?window.getSelection():document.getSelection?document.getSelection():document.selection.createRange().text))+'&v=6&jump=yes',%20'popup',%20'width=600,%20height=300,%20scrollbars,%20resizable'))">}
      "#{bmtag}#{imgtag}</a>".html_safe
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
    	navlinks.push(link_to_dialog "Add a Cookmark", new_recipe_path )
    	# navlinks.push(link_to_function("Add a Cookmark", "rcpAdd()" )) # navlink "Add a Cookmark", new_recipe_path, (@nav_current==:addcookmark)) 
    	navlinks.join('&nbsp|&nbsp').html_safe
    end
=begin    
    def feedback_link label
    	# We save the current URI in the feedback link so we can return here after feedback,
    	# and so the feedback can include the source
    	path = request.url.sub /[^:]*:\/\/[^\/]*/, '' # Strip off the protocol and host
    	navlink(label, "/feedbacks/new?backto=#{path}", (@nav_current==:feedback)) 
    end
=end
    
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
	def link_to_dialog(label, url)
    	link_to_function label, "applyForInteraction('#{url}');"
    end
	
	# Place the header for a dialog, including a call to its Onload function.
	# Currently handled this way (e.g., symbols that have been supported)
	#   :editRecipe
	#   :newRecipe
	def declareDialog( which, ttl)
	    classname = which.to_s
	    elmtDecl = %Q{
	      <div class='#{classname} dialog #{@partial}' title="#{ttl}">
	    }
        selector = 'div.'+classname
        onloadFcn = classname+"Onload"
	    onloadDecl = %Q{
	        <script type="text/javascript">
            $('#{selector}').ready(#{onloadFcn});
            </script>
        }
        (elmtDecl + onloadDecl).html_safe
    end
end
