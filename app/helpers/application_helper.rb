require "Domain"
require './lib/string_utils.rb'
# require 'suggestion_presenter'

module ApplicationHelper
  include ActionView::Helpers::DateHelper

  def image_with_error_recovery url, options={}
    image_tag url, options.merge( onError: "onImageError(this);")
  end

  def empty_msg
    unless @empty_msg.blank?
      content_tag :h4, @empty_msg
    end
  end

  # Nicely format a report of some quantity
  def count_report number, name, preface="", postscript="", threshold=1
    if !preface.is_a? String
      threshold, preface = preface, ""
    elsif !postscript.is_a? String
      threshold, postscript = postscript, ""
    end
    return "" if number<threshold
    if number == 0
      numstr = preface.blank? ? "No" : "no"
      name = name.strip.pluralize
    else
      numstr = number.to_s
      name = name.strip.pluralize if number > 1
    end
    "#{preface} #{numstr} #{name} #{postscript}".strip.gsub(/\s+/, ' ').html_safe
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
    "recipe_#{recipe.id}"
  end

  def feed_list_element_class entry
    "feedListElmt"+entry.id.to_s
  end

  # Return the id of the DOM element giving the time-since-touched for a recipe
  def touch_date_class recipe
    "touchtime#{recipe.id.to_s}"
  end

  # Present the date and time the recipe was last touched by its current user
  def touch_date_elmt entity
    if td = entity.touch_date
      stmt = "Last touched/viewed #{time_ago_in_words td} ago."
    else
      stmt = "Never touched or viewed"
    end
    content_tag :span, stmt, class: touch_date_class(entity)
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

  def question_section q, &block
    (
    content_tag(:h4, link_to(q, "#", class: "question_section"))+
        content_tag(:div, with_output_buffer(&block), class: "answer hide")
    ).html_safe
  end

  # A template element has embedded placeholders provided by the TemplateDecorator
  def template_element id, partial
    template = render(partial, entity: TemplateDecorator.new )
    content_tag :div,
                "",
                class: "template",
                id: id,
                :"data-template" => { string: template }.to_json
  end

  # Sign Me Up button for the home page, with contents varying according to, whether, e.g., a person is responding to an invitation
  def signup_button
    options = response_service.signup_button_options
    label = options.delete :label
    path = options.delete :path
    link_to_submit label, path, options.merge(:button_size => :lg, :button_style => :success)
  end

  # Pump pending notifications into flash notices
  def issue_notifications user
    notices = user.notifications_received.where(accepted: false).collect { |notification|
      notification.accept
    }.join('<br>'.html_safe)
    flash[:success] = notices unless notices.blank?
  end

  def debug_dump(params)
    "<div id=\"debug\">#{debug(params)}</div>".html_safe
  end

  def globstring(hsh)
    hsh.keys.each.collect { |key|
      key.to_s+": ["+(hsh[key] ? hsh[key].to_s : "nil")+"]"
    }.join(' ')
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
      "#{val}".html_safe
    end
  end

  def field_count what
    @decorator && @decorator.respond_to?(:arity) && @decorator.arity(what)
  end

  def present_field what=nil
    field_value(what) || %Q{%%#{(what || "").to_s}%%}.html_safe
  end

  def present_field_label what
    label = what.sub "_tags", ''
    case field_count(what)
      when nil, false
        "%%#{what}_label_plural%%"+"%%#{what}_label_singular%%"
      when 1
        label.singularize
      else
        label.pluralize
    end
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
                    dialog_submit_button(submit_label) +
                    dialog_cancel_button
                ).html_safe,
                class: "form-group actions"
  end

end
