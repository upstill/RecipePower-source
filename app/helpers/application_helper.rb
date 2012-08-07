module ApplicationHelper
    include ActionView::Helpers::DateHelper
    
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

  # Declare an image withinin an adjustable box. The images are downloaded by
  # the browser and their dimensions adjusted under Javascript by the fitImageOnLoad() function.
  def page_fitPic(picurl, id, float_ttl = true, selector=nil)
    # "fitPic" class gets fit inside pic_box with Javascript and jQuery
    idstr = "rcpPic"+id.to_s
    selector = selector || "##{idstr}"
	if picurl.blank? && float_ttl
	    %Q{<div class="centerfloat" id="#{idstr}">No Image Available</div>}.html_safe
	else
	    %Q{<img src="#{picurl}" class="fitPic" id="#{idstr}" onload="fitImageOnLoad('#{selector}')" alt="No Image Available">}.html_safe
	    # image_tag(picurl, class: "fitPic", id: idstr, onload: "fitImageOnLoad('#{selector}')", alt: "No Image Available")
	end
  end
  
  # Get all the img tags from a page and bundle them up as list items suitable for a picker
  def page_piclist url
      piclist = Site.piclist(url).collect { |url|
  		"<li class=\"pickerImage\"><img src=\"#{url}\" alt=\"#{url}\"/></li>\n"
  	  }
  end

  # Declare the list of thumbnails for picking a recipe's image.
  # It's sourced from the page by hoovering up all the <img tags that have
  # an appropriate file type.
  def page_choosePic picurl, pageurl, id
    piclist = page_piclist pageurl
  	if piclist.count > 0
        %Q{
            <div class="imagepicker">                                   
              <div class="preview">                                     
                #{page_fitPic picurl, id, false}  
              </div>                                                    
              <br><button class="title">Pick Image</button>
              <div class="content">                                     
                <div class="wrapper">                                   
                  <ul>#{piclist.join('')}</ul>                                             
                </div>                                                  
              </div>                                                    
            </div>}.html_safe
    else
            %q{<div class="imagepicker">
                <label for="recipe_picurl" id="recipe_pic_label">No Picture Available</label>
            </div>}.html_safe                                   
    end
  end
  
  # Local version of an image picker
  def site_choosePic site
      piclist = Site.piclist site.home+site.sample
 	  if piclist.count > 0
 	    pictab = []
 	    # divide piclist into rows of four pics apiece
        picrows = ""
        thumbNum = 0
        # Divide the piclist of URLs into rows of four, accumulating HTML for each row
 	    until piclist.empty?
 	        picrows <<  "<tr><td>"+
 	                    piclist.slice(0..3).collect{ |url| 
 	                      idstr = "thumbnail"+(thumbNum = thumbNum+1).to_s
 	                      "<div class = \"picCell\">"+
                    	    image_tag(url, class: "fitPic", id: idstr, onclick: "pickImg('input.icon_picker', 'div.preview img', '#{url}')", onload: "fitImageOnLoad('##{idstr}')", alt: "No Image Available")+
                    	  "</div>"
 	                    }.join('</td><td>')+
 	                    "</td></tr>"
 	        piclist = piclist.slice(4..-1) || [] # Returns nil when off the end of the array
        end
# picrows = ""
        picID = "rcpPic"+site.id.to_s
        %Q{
              <div class="preview">                                     
                #{page_fitPic site.logo, site.id, false, "div.preview img"}  
              </div> 
              <p class="airy">Pick one of the thumbnails<br>or type/paste the URL below, then click Okay.</p>                                                 
              <br class="clear"> <u>Preview</u>
              <input type="text" class="icon_picker" 
                        rel="jpg,png,gif" 
                        value="#{site.logo}" 
                        onchange="previewImg('input.icon_picker', 'div.preview img', 'input#site_logo')" />
              <br><table>#{picrows}</table>                                             
          }.html_safe
      else
          %q{<label for="recipe_picurl" id="recipe_pic_label">No Picture Available</label>}.html_safe                                   
      end
      
  end
      
    # Return the id of the DOM element giving the time-since-touched for a recipe
    def rr_touch_date_id recipe
        "touchtime#{recipe.id.to_s}"
    end

    # Present the date and time the recipe was last touched by the given user
    def rr_touch_date_elmt recipe
        if touched = Rcpref.touch_date(recipe.id, recipe.current_user)
            result = %Q{
               <div class="rcp_list_element_stats" id="#{rr_touch_date_id(recipe)}">
                 Last viewed #{time_ago_in_words(touched)} ago.
               </div>
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

  # Deploy the links for naming the user and/or signing up/signing in
  def user_status
    if user = current_user
       uname = user.handle
       ulink = link_to uname, users_profile_path # users_edit_path 
       ulogout = link_to "Sign Out", destroy_user_session_path, :method=>"delete"
       "<strong>#{ulink}</strong><span class=\"welcome_user\">&nbsp|&nbsp;#{ulogout}</span>".html_safe
     else
         link_to("Sign In", authentications_path)
     end + (current_user ? " | " + navlink("Invite", new_user_invitation_path, (@nav_current==:invite)) : "").html_safe
  end
  
  def bookmarklet
      imgtag = image_tag("Small_Icon.png", :alt=>"Cookmark", :class=>"logo_icon", width: "32px", height: "24px")
      bmtag = %q{<a class="bookmarklet" title="Cookmark" href="javascript:(function(){location.href='http://www.recipepower.com/recipes/new?url='+encodeURIComponent(window.location.href)+'&title='+encodeURIComponent(document.title)+'&notes='+encodeURIComponent(''+(window.getSelection?window.getSelection():document.getSelection?document.getSelection():document.selection.createRange().text))+'&v=6&jump=yes'})()">}
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

    def navlink(label, link, is_current)
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
    	navlinks.push(navlink "Add a Cookmark", new_recipe_path, (@nav_current==:addcookmark)) 
    	navlinks.join('  |  ').html_safe
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
end
