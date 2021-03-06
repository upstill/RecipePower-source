require 'Domain'
require './lib/string_utils.rb'
require 'class_utils.rb'
# require 'suggestion_presenter'
# require 'user_presenter.rb'
# Ensure all presenters are available
Dir[Rails.root.join('app', 'presenters', '*.rb')].each {|l| require l }

module ApplicationHelper
  include ActionView::Helpers::DateHelper

  def empty_msg
    unless @empty_msg.blank?
      content_tag :h4, @empty_msg
    end
  end

  # Nicely format a report of some quantity
  def count_report number, name, preface='', postscript='', threshold=1
    if !preface.is_a? String
      threshold, preface = preface, ''
    elsif !postscript.is_a? String
      threshold, postscript = postscript, ''
    end
    return '' if number<threshold
    if number == 0
      numstr = preface.blank? ? 'No' : 'no'
      name = name.strip.pluralize
    else
      numstr = number.to_s
      name = name.strip.pluralize if number > 1
    end
    "#{preface} #{numstr} #{name} #{postscript}".strip.gsub(/\s+/, ' ').html_safe
  end

  def present to_present, &block
    object = to_present.is_a?(Draper::Decorator) ? to_present.object : to_present
    if object && (const = const_for(object, 'Presenter'))
      presenter = const.new to_present, self
      if block_given?
        with_output_buffer { yield presenter }
      else
        presenter
      end
    end
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
    data = data_to_add_fields f, association, *initializers
    link_to name,
            '#',
            class: "add_fields #{'glyphicon glyphicon-plus' unless name.present?}",
            data: data
  end

  def data_to_add_fields f, association, *initializers
    new_object = f.object.send(association).klass.base_class.new *initializers
    new_object.id = new_object.object_id
    fields = f.simple_fields_for(association, new_object, child_index: new_object.id) do |builder|
      render association.to_s.singularize + '_fields', f: builder
    end
    # The initializing values are all declared in the data for purposes of client-side substitution
    (initializers[0] || {}).merge id: new_object.id, fields: fields.gsub("\n", '')
  end

  def recipe_popup(rcp)
    link_to image_tag('preview.png', title: 'Show the recipe in a popup window', class: 'preview_button'), rcp.url, target: '_blank', class: 'popup', id: "popup#{rcp.id.to_s}"
  end

  def recipe_list_element_golink_class recipe
    'rcpListGotag'+recipe.id.to_s
  end

  def recipe_list_element_class recipe
    'rcpListElmt'+recipe.id.to_s
  end

  def recipe_grid_element_class recipe
    "recipe_#{recipe.id}"
  end

  def feed_list_element_class entry
    'feedListElmt'+entry.id.to_s
  end

  # Return the id of the DOM element giving the time-since-touched for a recipe
  def touch_date_class recipe
    'touchtime' + recipe.id.to_s
  end

  # Present the date and time the recipe was last touched by its current user
  def touch_date_elmt entity
    if td = entity.touch_date
      stmt = "Last touched/viewed #{time_ago_in_words td} ago."
    else
      stmt = 'Never touched or viewed'
    end
    content_tag :span, stmt, class: touch_date_class(entity)
  end

  def title ttl=nil
    # Any controller can override the default title of controller name
    "RecipePower | #{ttl || response_service.title}"
  end

  def logo(small=false)
    link_to image_tag('RPlogo.png', :alt => 'RecipePower', :id => 'logo_img'+(small ? '_small' : '')), root_path
  end

  def bookmarklet_script
    "javascript:(function%20()%20{var%20s%20=%20document.createElement(%27script%27);s.setAttribute(%27language%27,%27javascript%27);s.setAttribute(%27id%27,%20%27recipePower-injector%27);s.setAttribute(%27src%27,%27#{rp_url}/recipes/capture.js?recipe[url]=%27+encodeURIComponent(window.location.href)+%27&recipe[title]=%27+encodeURIComponent(document.title)+%27&recipe[rcpref][comment]=%27+encodeURIComponent(%27%27+(window.getSelection?window.getSelection():document.getSelection?document.getSelection():document.selection.createRange().text))+%27&v=6&jump=yes%27);document.body.appendChild(s);}())"
  end

  def bookmarklet
    imgtag = image_tag('InstallCookmarkButton.png', class: 'bookmarklet', style: 'display: inline-block', alt: 'Cookmark')
    content_tag :a, imgtag, href: bookmarklet_script, title: 'Cookmark', class: 'bookmarklet'
  end

  def question_section q, &block
    (
    content_tag(:h4, link_to(q, '#', class: 'question_section'))+
        content_tag(:div, with_output_buffer(&block), class: 'answer hide')
    ).html_safe
  end

  # A template element has embedded placeholders provided by the TemplateDecorator
  def template_element id, partial
    template = render(partial, entity: TemplateDecorator.new )
    content_tag :div,
                '',
                class: 'template',
                id: id,
                :'data-template' => { string: template }.to_json
  end

  def debug_dump(params)
    "<div id=\"debug\">#{debug(params)}</div>".html_safe
  end

  def globstring(hsh)
    hsh.keys.each.collect { |key|
      key.to_s+': ['+(hsh[key] ? hsh[key].to_s : 'nil')+']'
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
      name = "#{action}_#{params[:controller].singularize}"
      modal_dialog name+' new-style green', title, options.slice!(:title, :action) # Pass other options through to modal
    else
      "<h3>#{title}</h3>".html_safe+options[:body_contents]
    end
  end

  # Wrap a link in a link to invitations/diversion, so as to report
  # the invitee getting diverted to the reference
  def invitation_diversion_link url, invitee
    divert_user_invitation_url(invitation_token: invitee.raw_invitation_token, url: CGI::escape(url))
  end

  # Generic termination buttons for dialogs--or any other forms
  def form_actions f, options = {}
    cancel_path = options[:cancel_path] || default_next_path
    submit_label = options[:submit_label] || 'Save'
    content_tag :div,
                ((block_given? ? yield : '') +
                    dialog_submit_button(submit_label) +
                    dialog_cancel_button
                ).html_safe,
                class: 'form-group actions'
  end

  # Get jQuery from the Google CDN, falling back to the version in jquery-rails if unavailable
  def jquery_include_tag use_cdn=true, use_jq2=false
    if use_jq2
      localfile = 'jquery2'
      version = Jquery::Rails::JQUERY_2_VERSION
    else
      localfile = 'jquery'
      version = Jquery::Rails::JQUERY_VERSION
    end
    [ (javascript_include_tag("//ajax.googleapis.com/ajax/libs/jquery/#{version}/jquery.min.js") if use_cdn),
      javascript_tag("window.jQuery || document.write(unescape('#{javascript_include_tag(localfile).gsub('<','%3C')}'))")
    ].join("\n").html_safe
  end


  # The Bootstrap version is that provided by bootstrap-sass
  def bootstrap_css_include_tag use_cdn=true
    if use_cdn
      # The version may include a maintenance release number
      version = Bootstrap::VERSION.split('.')[0..2].join('.')
      stylesheet_link_tag('bootstrap_preface') +
      stylesheet_link_tag("//maxcdn.bootstrapcdn.com/bootstrap/#{version}/css/bootstrap.min.css") +
      stylesheet_link_tag("//maxcdn.bootstrapcdn.com/bootstrap/#{version}/css/bootstrap-theme.min.css")
    else
      stylesheet_link_tag 'bootstrap_import.css'
    end
  end

  # The Bootstrap version is that provided by bootstrap-sass
  def bootstrap_js_include_tag use_cdn=true
    local_bs = javascript_include_tag 'bootstrap.js'
    if use_cdn
      # The version may include a maintenance release number
      version = Bootstrap::VERSION.split('.')[0..2].join('.')
      bs = (stylesheet_link_tag('bootstrap_import.css') + local_bs).gsub '<', '%3C'
      # Follow the bootstrap CDN pull with a test and fallback to the local version
      javascript_include_tag("//maxcdn.bootstrapcdn.com/bootstrap/#{version}/js/bootstrap.min.js") +
      javascript_tag(%Q{
        if(typeof $().emulateTransitionEnd != 'function') {
          document.write(unescape('#{bs}'));
        }
      })
    else
      local_bs
    end
  end

  def entity_approval decorator
    entity = decorator.object
    labels =
    case entity
      when Site
        %w{ Expose Visible Hide Hidden }
      when Feed
        %w{ Approve Approved Block Blocked }
      else
        []
    end
    str = case entity.approved
            when true
              labels[1] + ' '
            when false
              labels[3] + ' '
            else
              ''
          end
    # NB: entities can have nil approval status, in which case both buttons should show
    str << link_to_submit(labels[0],
                          polymorphic_path( [:approve, decorator.as_base_class], approve: 'Y'),
                          button_style: 'success',
                          button_size: 'xs',
                          method: 'POST'
    ) unless entity.approved == true
    str << link_to_submit(labels[2],
                          polymorphic_path( [:approve, decorator.as_base_class], approve: 'N'),
                          button_style: 'danger',
                          button_size: 'xs',
                          method: 'POST'
    ) unless entity.approved == false
    content_tag :span, str.html_safe, :id => dom_id(entity)
  end

  def entity_approval_replacement decorator
    [ "span##{dom_id decorator.object}", entity_approval(decorator) ]
  end

  # Provide a labelled presentation of a collection of entities
  # scope_or_array: either a scope for items, or a preloaded array
  # label: string to form a header
  # options:
  # limit: max number of items to display
  # fixed_label: don't include a count of items
  # orig_size: size of the set from which the scope or array are drawn, for reporting purposes
  def report_items scope_or_array, label, options={}, &block
    label = labelled_quantity((options[:orig_size] || scope_or_array.count), label).sub(/^1 /, '') if label.present? && !options[:fixed_label]
    if limit = options[:limit]
      scope_or_array = (scope_or_array.is_a?(Array) ? scope_or_array[0..limit] : scope_or_array.limit(limit))
    end
    summs = if block_given?
              scope_or_array.collect &block
            elsif scope_or_array.first.is_a? ApplicationRecord
              scope_or_array.collect { |item| homelink item }
            else
              scope_or_array
            end
    return summs unless label.present?
    if summs.count > 1
      [label.html_safe, summs]
    elsif summs.present?
      "#{label}: ".html_safe + summs.first
    end
  end

  def format_table_tree strtree, indent=''.html_safe
    if strtree
      return indent + strtree if strtree.is_a?(String)
      safe_join strtree.collect { |item|
                  case item
                    when String
                      (indent + item) if item.present?
                    when Array
                      format_table_tree item, '&nbsp;&nbsp;&nbsp;&nbsp;'.html_safe + indent
                  end
                }.compact, '<br>'.html_safe
    end
  end

end
