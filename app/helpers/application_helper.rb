require "Domain"
require './lib/controller_utils.rb'
module ApplicationHelper
    include ActionView::Helpers::DateHelper

    def present(object, klass = nil)
      klass ||= "#{object.class}Presenter".constantize
      presenter = klass.new(object, self)
      yield presenter if block_given?
      presenter
    end
    
    def resource_name
      :user
    end

    def resource
      @resource ||= User.new( :remember_me => true )
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
  def page_fitPic(picurl, id = "", placeholder_image = "NoPictureOnFile.png", selector=nil)
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
  def pic_field(obj, attribute, form, editable = true, fallback_img="NoPictureOnFile.png")
    picurl = obj.send(attribute)
    preview = content_tag(
      :div, 
      page_fitPic(picurl, obj.id, fallback_img, "div.pic_preview img")+
                form.text_field(attribute, rel: "jpg,png,gif", hidden: true, class: "hidden_text" ),
      class: "pic_preview"
    )
    picker = editable ?
      content_tag(:div,
            link_to( "Pick Picture", "/", :data=>"recipe_picurl;div.pic_preview img", :class => "pic_picker_golink")+
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
  
  def button_to(imagelink, path, options={} )
    link_to(
      image_tag(imagelink, class: "back_button" ), 
      path,
      options
    )
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
      prompt = "There are no pictures on the recipe's page, but you can paste a URL into the text box below."
    else
      tblstr = "<br><table>#{picrows}</table>"
      prompt = "Pick one of the thumbnails, then click Okay.<br><br>Or, type or paste the URL of an image into the text box, if that's your pleasure.".html_safe
    end
    content_tag( :div, 
      page_fitPic( picurl, id, "NoPictureOnFile.png", "div.preview img" ),
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

  def bookmarklet
    imgtag = image_tag("cookmark_button.png", class:"bookmarklet", style: "display: inline-block", alt:"Cookmark") 
    if Rails.env.development? || true
      # New bookmarklet
      bmtag = %Q{<a class="bookmarklet" title="Cook Me Later" href="javascript:(function%20()%20{var%20s%20=%20document.createElement(%27script%27);s.setAttribute(%27language%27,%27javascript%27);s.setAttribute(%27id%27,%20%27recipePower-injector%27);s.setAttribute(%27src%27,%27http://#{current_domain}/recipes/capture.js?recipe[url]=%27+encodeURIComponent(window.location.href)+%27&recipe[title]=%27+encodeURIComponent(document.title)+%27&recipe[rcpref][comment]=%27+encodeURIComponent(%27%27+(window.getSelection?window.getSelection():document.getSelection?document.getSelection():document.selection.createRange().text))+%27&v=6&jump=yes%27);document.body.appendChild(s);}())">}
    else
      # Old bookmarklet
      bmtag = %Q{<a class="bookmarklet" title="Cookmark" href="javascript:void(window.open('http://#{current_domain}/recipes/new?url='+encodeURIComponent(window.location.href)+'&title='+encodeURIComponent(document.title)+'&notes='+encodeURIComponent(''+(window.getSelection?window.getSelection():document.getSelection?document.getSelection():document.selection.createRange().text))+'&v=6&jump=yes',%20'popup',%20'width=600,%20height=300,%20scrollbars,%20resizable'))">}
    end
    (bmtag+imgtag+"</a>").html_safe
  end
  
  def header_menu

    item_list = [
      link_to_modal( "Profile", users_profile_path( section: "profile" )),
      link_to_modal( "Sign-in Services", authentications_path),
      link_to_modal( "Invite", new_user_invitation_path ),
      link_to( "Sign Out", destroy_user_session_path, :method => "delete") 
    ]
  
    item_list += [
  		"<hr>",
  		link_to( "Admin", admin_path),
  		link_to_function( "Refresh Masonry", "RP.collection.justify();" ),
  		link_to_modal( "Need to Know", popup_path(name: "need_to_know"))
  	] if permitted_to? :admin, :pages
  
    header_link =
    link_to (current_user.handle+'<b class="caret"></b>').html_safe, "#",
      class: "dropdown-toggle", data: { toggle: "dropdown" }, role: "button"

    menu = 
    content_tag :ul, 
      ("<li>#{ item_list.join("</li><li>") }</li>").html_safe, 
      class: "dropdown-menu", 
      role: "menu",
      :"aria-labelledby" => "userMenuLabel"
      
    (header_link+menu).html_safe
  end
    
  def footer_navlinks
  	navlinks = []
  	navlinks << link_to_modal("About", popup_path(name: "pages/about")) 
  	navlinks << link_to_modal("Contact", popup_path(name: "pages/contact")) 
  	navlinks << link_to("Home", home_path, class: "nav_link") 
  	navlinks << link_to_modal("FAQ", popup_path(name: "pages/faq")) 
  	infolinks = 
  	  [ 
  	    link_to_modal("Need to Know", popup_path(name: "pages/need_to_know")),
	      link_to_modal("Cookmark Button", popup_path(name: "pages/starting_step2") )
	    ]
  	# navlinks << feedback_link("Feedback")
  	[ navlinks.join('  |  '), infolinks.join('  |  ') ].compact.join("<br>").html_safe
  end
  
  def question_section q, &block
    (
      content_tag(:h4, link_to_function(q, "RP.showhide(event);"))+
      content_tag(:div, with_output_buffer(&block), class: "answer hide")
    ).html_safe
  end
  
  # If there are any tasks awaiting which need a login, set up the appropriate one.
  # Returning nil implies to preload the signup dialog
  def login_setup
    return if session[:on_tour]
    if session[:invitation_token]
      # load the invitation-acceptance dialog. If the user isn't on tour, set it to
      # trigger when the page is loaded
			link_to "", accept_user_invitation_path(invitation_token: session[:invitation_token]), class: "trigger"
    elsif token = deferred_notification
			@user = Notification.find_by_notification_token(token).target
			link_to "", new_user_session_path(user: { id: @user.id, email: @user.email } ), class: "trigger" 
    elsif data = deferred_collect(false)
      debugger
			@user = User.find data[:uid]
			link_to "", new_authentication_path, class: "trigger" 
		end
	end
  
  def signup_button
    unless current_user
      if session[:invitation_token]
        label = "Accept Invitation" 
        path = accept_user_invitation_path(invitation_token: session[:invitation_token] )
        button_to_modal(label, path, class: "btn btn-large btn-success" ) 
      elsif token = deferred_notification
  			@user = Notification.find_by_notification_token(token).target
  			button_to_modal "Take Share", new_user_session_path(user: { id: @user.id, email: @user.email } ), class: "btn btn-large btn-success" 
      else
        label = "Sign Me Up"
        selector = "div.dialog.signup"
        path = collection_path()
        button_to_modal(label, path, class: "btn btn-large btn-success", selector: selector ) 
      end
    end
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
	
	def globstring(hsh)
    hsh.keys.each.collect { |key| 
      key.to_s+": ["+(hsh[key] ? hsh[key].to_s : "nil")+"]"
    }.join(' ')
  end

   def pagination_link (text, pagenum, url)
     # "<span value='#{p.to_s}' class='pageclickr'>#{p.to_s}</span>"
     # We install the actual pagination handler in RPquery.js::queryTabOnLoad
     link_to_function text.html_safe, ";", class: "pageclickr", value: pagenum.to_s, :"data-url" => url
   end

   def pagination_links(npages, cur_page, url )
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
end
