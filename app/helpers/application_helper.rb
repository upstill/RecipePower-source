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
    fields = f.simple_fields_for(association, new_object, child_index: id) do |builder|
      render(association.to_s.singularize + "_fields", f: builder)
    end
    link_to(name, '#', class: "add_fields", data: {id: id, fields: fields.gsub("\n", "")} )
  end
  
  def recipe_popup( rcp )
      link_to image_tag("preview.png", title:"Show the recipe in a popup window", class: "preview_button"), rcp.url, target: "_blank", class: "popup", id: "popup#{rcp.id.to_s}"        
  end

  # Declare an image which gets resized to fit upon loading
  # id -- used to define an id attribute for this picture (all fitpics will have class 'fitPic')
  # float_ttl -- indicates how to handle an empty URL
  # selector -- specifies an alternative selector for finding the picture for resizing
  def page_fitPic(picurl, id = "")
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
    	  image_tag("NoPictureOnFile.png",
          class: "fitPic",
          id: idstr,
          onload: 'doFitImage(event);',
          alt: "Some Image Available")
      end
#    end
    end

    # Same protocol, only image will be scaled to 100% of the width of its parent, with adjustable height
    def page_width_pic(picurl, id = "", placeholder_image = "NoPictureOnFile.png", selector=nil)
      logger.debug "page_width_pic placing #{picurl.blank? ? placeholder_image : picurl.truncate(40)}"
      # "fitPic" class gets fit inside pic_box with Javascript and jQuery
      idstr = "rcpPic"+id.to_s
      selector = selector || "##{idstr}"
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

#  def pic_picker picurl, pageurl, id
#    pic_picker_shell (pic_picker_contents picurl, pageurl, id)
#  end

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
            link_to( "Pick Picture", "/", :data=>"recipe_picurl;div.pic_preview img", :class => "pic_picker_golink hide")+
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
    "RecipePower | #{ttl || @Title || params[:controller].capitalize}"
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
  
  def bookmarklet_script
    "javascript:(function%20()%20{var%20s%20=%20document.createElement(%27script%27);s.setAttribute(%27language%27,%27javascript%27);s.setAttribute(%27id%27,%20%27recipePower-injector%27);s.setAttribute(%27src%27,%27http://#{current_domain}/recipes/capture.js?recipe[url]=%27+encodeURIComponent(window.location.href)+%27&recipe[title]=%27+encodeURIComponent(document.title)+%27&recipe[rcpref][comment]=%27+encodeURIComponent(%27%27+(window.getSelection?window.getSelection():document.getSelection?document.getSelection():document.selection.createRange().text))+%27&v=6&jump=yes%27);document.body.appendChild(s);}())"
  end

  def bookmarklet
    imgtag = image_tag("cookmark_button.png", class:"bookmarklet", style: "display: inline-block", alt:"Cookmark") 
    content_tag :a, imgtag, href: bookmarklet_script, title: "Cookmark", class: "bookmarklet"
  end
  
  def header_menu
    
    return "" unless current_user

    item_list = [
      link_to_modal( "Profile", users_profile_path( section: "profile" )),
      link_to_modal( "Sign-in Services", authentications_path),
      link_to_modal( "Invite", new_user_invitation_path ),
      link_to( "Sign Out", destroy_user_session_path, :method => "delete") 
    ]
  
    item_list += [
  		"<hr>",
  		link_to( "Admin", admin_path),
  		link_to( "Refresh Masonry", "#", onclick: "RP.collection.justify();" ),
  		link_to( "Address Bar Magic", "#", onclick: "RP.getgo('#{home_path}', 'http://local.recipepower.com:3000/bar.html##{bookmarklet_script}')" ), 
  		link_to( "Bookmark Magic", "#", onclick: "RP.bm('Cookmark', '#{bookmarklet_script}')"), 
  		link_to( "Stream Test", "#", onclick: "RP.stream.buffer_test();" ),
  		link_to_modal("Step 3", popup_path("starting_step3"))
  	] if permitted_to? :admin, :pages
  
    header_link =
    link_to (current_user.handle+'<b class="caret"></b>').html_safe, "#",
      class: "dropdown-toggle", data: { toggle: "dropdown" }, role: "button"

    menu = 
    content_tag :ul, 
      ("<li>#{ item_list.join("</li><li>") }</li>").html_safe, 
      class: "dropdown-menu", # "nav navbar-nav", 
      role: "menu",
      :"aria-labelledby" => "userMenuLabel"
      
    content_tag :li,
      (header_link+menu),
      class: "dropdown"
  end
    
  def footer_navlinks for_mobile=false
  	navlinks = []
  	navlinks << link_to_modal("About", about_path) 
  	navlinks << link_to_modal("Contact", contact_path) 
  	navlinks << link_to("Home", home_path, class: "nav_link") 
  	navlinks << link_to_modal("FAQ", faq_path) 
  	infolinks = 
  	  [ 
  	    link_to_modal("Need to Know", popup_path("need_to_know")),
	      link_to_modal("Cookmark Button", popup_path("starting_step2") )
	    ]
  	# navlinks << feedback_link("Feedback")
  	if for_mobile 
  	  navlinks.flatten.join(' ').html_safe
  	else
  	  [ navlinks.join('  |  '), infolinks.join('  |  ') ].compact.join("<br>").html_safe
  	end
  end
  
  def question_section q, &block
    (
      content_tag(:h4, link_to(q, "#", class: "question_section"))+
      content_tag(:div, with_output_buffer(&block), class: "answer hide")
    ).html_safe
  end
  
  # If there are any tasks awaiting which need a login, set up the appropriate one.
  # Returning nil implies to preload the signup dialog
  def login_setup 
    if session[:on_tour]
	    render(partial: "shared/signup_dialog")
    elsif it = session[:invitation_token]
      # load the invitation-acceptance dialog. If the user isn't on tour, set it to
      # trigger when the page is loaded
      session.delete :invitation_token
			link_to_modal "", accept_user_invitation_path(invitation_token: it), class: "trigger"
    elsif token = deferred_notification
			@user = Notification.find_by_notification_token(token).target
			link_to "", new_user_session_path(user: { id: @user.id, email: @user.email } ), class: "trigger" 
    elsif data = deferred_collect(false)
      if data[:uid]
  			@user = User.find data[:uid]
  			link_to "", new_authentication_path, class: "trigger" 
  		else
  		  link_to "", new_user_path, class: "trigger" 
  		end
	  else
	    render "shared/signup_dialog"
		end
	end
  
  def signup_button
    unless current_user
      if session[:invitation_token]
        label = "Accept Invitation" 
        path = accept_user_invitation_path(invitation_token: session[:invitation_token] )
        button_to_modal(label, path, class: "btn btn-lg btn-success trigger" ) 
      elsif token = deferred_notification
  			@user = Notification.find_by_notification_token(token).target
  			button_to_modal "Take Share", new_user_session_path(user: { id: @user.id, email: @user.email } ), class: "btn btn-lg btn-success trigger" 
      else
        label = "Sign Me Up"
        selector = "div.dialog.signup"
        path = new_user_registration_path()
        button_to_modal(label, path, class: "btn btn-lg btn-success", selector: selector ) 
      end
    end
  end

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
     url = assert_query url, cur_page: pagenum
     link_to text.html_safe, url, class: "pageclickr", remote: true, method: :POST, "data-type" => :JSON
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

=begin Defunct: supplanted by page_or_modal
  # Helper for "standard" template which goes to either a page or a modal dialog,
  # depending on context. The content is found in <controller>/<action>_content,
  # and if robomodal is false, the modal dialog is in <controller>/<action>_modal
  def simple_page ttl, robomodal = false
    if response_service.dialog?
      if robomodal
        # The content is simple enough to render in a generic popup using the content
        simple_modal params[:action], ttl, style: "margin: 0px 15px;" do
        	render params[:action]+"_content"
        end
      else
        render params[:action]+"_modal"
      end
    else
      content_tag :div, 
        content_tag(:h2, ttl, class: "med")+
        render(params[:action]+"_content"),
      class: "text_block"
    end
  end
=end

  def popup_path(name)
    "/popup/#{name}"
  end

  # Ensure that the popup includes a hashtag for showing the given popup upon page load
  def assert_popup popup_request, url
    popup_request ||= session[:popup]
    return url if popup_request.blank?
    uri = URI(url)
    uri.fragment = CGI::escape "dialog:popup/#{popup_request}"
    session[:popup] = popup_request
    uri.to_s
  end

  def check_popup name
    session.delete(:popup) if session[:popup] && (session[:popup] =~ /^#{name}\b/)
  end

  # Render content, either for a page or a dialog
  def page_or_modal options={}, &block
    title = options[:title] || @Title
    action = options[:action] || params[:action]
    options[:body_contents] = with_output_buffer(&block)
    if response_service.dialog?
      name = :"#{action}_#{params[:controller].singularize}"
      modal_dialog name, title, options.slice!(:title, :action) # Pass other options through to modal
    else
      "<h3>#{title}</h3>".html_safe+options[:body_contents]
    end
  end
  
  # Wrap a link in a link to invitations/diversion, so as to report 
  # the invitee getting diverted to the reference
  def invitation_diversion_link url, invitee
    divert_user_invitation_url(invitation_token: invitee.raw_invitation_token, url: CGI::escape(url))
  end

  def field_value what=nil
    return form_authenticity_token if what && (what == "authToken")
    if val = @decorator && @decorator.extract(what)
      val.html_safe
    end
  end

  def present_field what=nil
    field_value(what) || %Q{%%#{(what || "").to_s}%%}.html_safe
  end

  def present_field_wrapped what=nil
    content_tag :span,
                present_field(what),
                class: "hide-if-empty"
  end

  # Set up a remote interaction via the submit javascript module
  def button_to_submit label, url, options={}
    options[:class] = "btn btn-default btn-xs submit"
    options.merge! remote: true
    link_to label, url, options
  end

end
