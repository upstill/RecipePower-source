require "Domain"
require './lib/controller_utils.rb'
require './lib/string_utils.rb'
require 'suggestion_presenter'

module ApplicationHelper
  include ActionView::Helpers::DateHelper

  def image_with_error_recovery url, options={}
    image_tag url, options.merge( onError: "onImageError(this);")
  end

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
    @resource ||= User.new(:remember_me => true)
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
    link_to(name, '#', style: "display:none", class: "add_fields", data: {id: id, fields: fields.gsub("\n", "")})
  end

  def recipe_popup(rcp)
    link_to image_tag("preview.png", title: "Show the recipe in a popup window", class: "preview_button"), rcp.url, target: "_blank", class: "popup", id: "popup#{rcp.id.to_s}"
  end

  def recipe_list_element_golink_class recipe
    "rcpListGotag"+recipe.id.to_s
  end

  def recipe_list_element_class recipe
    "rcpListElmt"+recipe.id.to_s
  end

  def recipe_grid_element_class recipe
    "rcpGridElmt"+recipe.id.to_s
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
      render("shared/" + association.to_s.singularize + "_fields_" + inex.to_s, :f => builder)
    end
    new_object = {:scale_id => 2}
    fields2 = f.fields_for(association, new_object, :child_index => "new_#{association}") do |builder|
      render("shared/" + association.to_s.singularize + "_fields_" + inex.to_s, :f => builder)
    end
    # Collect the options from the available ratings, each having
    # value equal to the scale's id, with a title from the scale's name, so 
    # that the javascript function can use it in the rating label(s)
    opcs = Scale.find(:all).collect { |s|
      # Only allow selection of scales that are unrated thus far
      ratings.index { |r| r.scale_id == s.id } ? "" : "<option value=\"#{s.id}\" title=\"#{s.minlabel} to #{s.maxlabel} \" >#{s.name}</option>"
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
    "RecipePower | #{ttl || response_service.title}"
  end

  def logo(small=false)
    link_to image_tag("RPlogo.png", :alt => "RecipePower", :id => "logo_img"+(small ? "_small" : "")), root_path
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
    imgtag = image_tag("cookmark_button.png", class: "bookmarklet", style: "display: inline-block", alt: "Cookmark")
    content_tag :a, imgtag, href: bookmarklet_script, title: "Cookmark", class: "bookmarklet"
  end

  def friends_menu_items
    current_user.followees[0..6].collect { |u|
      navlink u.handle, "/users/#{u.id}/collection", id: dom_id(u)
    }.push navlink("Make a Friend...", users_path)
  end

  def collection_menu_items
    [
        navlink("My Goodies", "/users/#{current_user_or_guest_id}/collection"),
        navlink("All the Goodies", "/users/#{current_user_or_guest_id}/biglist"),
        navlink("Recently Viewed", "/users/#{current_user_or_guest_id}/recent")
    ]
  end

  def goody_bags_menu_items
    result = current_user.subscriptions(:own)[0..6].collect { |l|
      navlink l.name, list_path(l), id: dom_id(l)
    }
    result + [
        "<hr>".html_safe,
        navlink("Browse for Goody Bags...", lists_path),
        navlink("Start a Goody Bag...", new_list_path, :as => :dialog)
    ]
  end

  def feeds_menu_items
    result = current_user.feeds[0..12].collect { |f|
      navlink truncate(f.title, length: 30), feed_path(f), id: dom_id(f)
    }
    result + [
        "<hr>".html_safe,
        navlink("Browse for More Feeds...", feeds_path)
    ]
  end

  def header_menu_items

    item_list = [
        # navlink( "Profile", users_profile_path( section: "profile" ), :as => :dialog),
        navlink("Sign-in Services", authentications_path, :as => :dialog),
        navlink("Invite", new_user_invitation_path, :as => :dialog),
        navlink("Sign Out", destroy_user_session_path, :method => "delete", :as => :page)
    ]

    item_list += [
        "<hr>".html_safe,
        link_to_modal("Add Cookmark", new_recipe_path),
        link_to("Admin", admin_path),
        link_to("Refresh Masonry", "#", onclick: "RP.collection.justify();"),
        link_to("Address Bar Magic", "#", onclick: "RP.getgo('#{home_path}', 'http://local.recipepower.com:3000/bar.html##{bookmarklet_script}')"),
        link_to("Bookmark Magic", "#", onclick: "RP.bm('Cookmark', '#{bookmarklet_script}')"),
        link_to("Stream Test", "#", onclick: "RP.stream.buffer_test();"),
        link_to_modal("Step 3", popup_path("starting_step3"))
    ] if permitted_to? :admin, :pages

    item_list
  end

  def header_menu label=nil
    label ||= current_user.handle

    return "" unless current_user

    header_link =
        link_to (label+'<b class="caret"></b>').html_safe, "#",
                class: "dropdown-toggle", data: {toggle: "dropdown"}, role: "button"

    items = ("<li>" + header_menu_items.join("</li>\n<li>") + "</li>").html_safe

    menu =
        content_tag :ul,
                    items,
                    class: "dropdown-menu", # "nav navbar-nav",
                    role: "menu",
                    :"aria-labelledby" => "userMenuLabel"

    content_tag :li,
                (header_link+menu),
                class: "dropdown"
  end

  def footer_navlinks for_mobile=false
    navlinks = []
    navlinks << navlink("About", about_path, :as => :dialog)
    navlinks << navlink("Contact", contact_path, :as => :dialog)
    navlinks << link_to("Home", home_path, class: "nav_link")
    navlinks << navlink("FAQ", faq_path, :as => :dialog)
    infolinks =
        [
            navlink("Need to Know", popup_path("need_to_know"), :as => :dialog),
            navlink("Cookmark Button", popup_path("starting_step2"), :as => :dialog)
        ]
    # navlinks << feedback_link("Feedback")
    if for_mobile
      navlinks.flatten.join(' ').html_safe
    else
      [navlinks.join('  |  '), infolinks.join('  |  ')].compact.join("<br>").html_safe
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
  def preloads
    if current_user
      render partial: 'recipes/edit_template', recipe: nil
    else
      render partial: "registrations/new_modal"
    end
  end

  # Sign Me Up button for the home page, with contents varying according to, whether, e.g., a person is responding to an invitation
  def signup_button
    unless current_user
      options = response_service.signup_button_options
      label = options.delete :label
      path = options.delete :path
      button_link label, path, :dialog, :default, :xl, options
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


  def popup_path(name)
    "/popup/#{name}"
  end

  # Ensure that the popup includes a hashtag for showing the given popup upon page load
  def assert_popup popup_request, url
    popup_request ||= session[:popup]
    return url if popup_request.blank?
    fragment = CGI::escape("#dialog:popup/#{popup_request}")
    uri = URI(url)
    if uri.path == "/redirect/go"
      # The fragment needs to be inserted into the target of the redirect, inside quotes for precedent's sake
      q = uri.query
      q.split('&').each { |param|
        key, value = param.split '='
        if key == 'to'
          unquoted = value.sub /^"?([^"]*)"?/, '\\1' # Remove any enclosing quotes
          # uri.query = q.sub value, %Q{"#{unquoted+fragment}"}
          url = assert_query uri.to_s, to: %Q{"#{unquoted+fragment}"}
          return url
        end
      }
    else
      uri.fragment = fragment
    end
    session[:popup] = popup_request
    uri.to_s
  end

  def check_popup name
    session.delete(:popup) if session[:popup] && (session[:popup] =~ /^#{name}\b/)
  end

  # Render content, either for a page or a dialog
  def page_or_modal options={}, &block
    title = options[:title] || response_service.title
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

  # Generic termination buttons for dialogs--or any other forms
  def form_actions f, options = {}
    cancel_path = options[:cancel_path] || collection_path
    submit_label = options[:submit_label] || "Save"
    content_tag :div,
                ((block_given? ? yield : "") +
                    f.submit(submit_label, class: "dialog-submit-button btn btn-success") +
                    link_to("Cancel", cancel_path, class: "dialog-cancel-button btn btn-info")
                ).html_safe,
                class: "form-group actions"
  end

  # Define one element of the navbar. Could be a
  # -- simple label (no go_path and no block given)
  # -- link (valid go_path but no block)
  # -- Full-bore dropdown menu (block given), with or without a link at the top (go_path given or not)
  def navtab which, menu_label, go_path=nil, as=nil
    options={as: as}
    id = "#{which}-navtab" # id used for the menu item
    if which == (@active_menu || response_service.active_menu)
      active = "active"
    else
      options[:style] = "color: #999;"
    end

    # The block should produce an array of menu items (links, etc.)
    if block_given? && (menu_items = yield) && !menu_items.empty?
      itemlist =
          content_tag :ul,
                      menu_items.collect { |item| content_tag :li, item }.join("\n").html_safe,
                      class: "dropdown-menu"
      menu_label << content_tag(:span, "", class: "caret")
      dropdown = "dropdown"
    end

    content = navlink menu_label.html_safe, go_path, true, options

    content_tag :li,
                "#{content} #{itemlist}".html_safe,
                {
                    id: id,
                    class: "master-navtab #{dropdown} #{active}"
                }
  end

  # Declare one navlink with appropriate format and query parameters
  def navlink label, path_or_options, is_menu_header=false, options={}
    if is_menu_header.is_a? Hash
      is_menu_header, options = false, is_menu_header
    end
    # The menu headers may or may not have links, but they do have dropdown menus
    if is_menu_header
      options[:class] = "dropdown-toggle #{options[:class]}"
      options[:data] ||= {}
      options[:data][:toggle] = "dropdown"
    end
    flavored_link label, path_or_options, options.delete(:as), options
  end

end
