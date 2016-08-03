module LinkHelper

  # A wrapper for flavored_link which asserts either 1) button options for Bootstrap, or 2) glyphs via sprites
  # kind: primary, info, success, warning, danger, inverse, link http://getbootstrap.com/2.3.2/base-css.html#buttons
  # size: large, small, mini
  def button_to_submit label, path_or_options, kind='default', size=nil, options={}
    if kind.kind_of? Hash
      kind, size, options = :default, nil, kind
    elsif size.kind_of? Hash
      size, options = nil, size
    end
    kind = kind.to_s
    options = options.clone
    with_form = options.delete :with_form
    class_str = (options[:class] || '').gsub(/btn[-\w]*/i, '') # Purge the class of existing button classes
    if kind.sub! /^glyph-/, '' # 'kind' starting with 'glyph' denotes sprite
      label = sprite_glyph(kind, size) + (label.present? ? ('&nbsp;'+label) : '').html_safe
    else # Otherwise, we use a Bootstrap button
      class_str << " btn btn-#{kind}"
      class_str << " btn-#{size}" if size
    end
    options[:class] = class_str

    link_options = linkto_options path_or_options, options
    path = link_options.delete :path
    if with_form
      link_options[:class].sub! /\bsubmit\b/, '' # Remove the 'submit' class from the button
      button_to label, path_or_options, link_options.merge(:remote => true, :form_class => 'ujs-submit')
    else # If the submission isn't a simple get request, we use a (secure) form
      link_to label, path, link_options
    end

  end

  def link_to_submit label, path_or_options, options={}
    link_options = linkto_options path_or_options, options
    path = link_options.delete :path
    link_to label, path, link_options
  end

  # Provide a hash of options for link_to to hit a URL using the RP.submit javascript module,
  # with options for confirmation (:confirm_msg) and waiting (:wait_msg)
  # NB: options are used as follows:
  # format may be stipulated as :html to get a normal link; otherwise, the link will submit for JSON
  # mode can be one of:
  #  == :modal to fetch a dialog via JSON
  #  == :injector to get a dialog for foreign sites via JSON
  # :template, :trigger, :submit, and :preload are classes on the link for triggering submit behavior
  # :id, :class, :style, :data, :onclick, :rel and :method are passed to link_to to create attributes
  # ...all other options get folded into the data attribute of the link
  def linkto_options path_or_options, options={}
    query_option_names = [ :mode ] # These get folded into the query UNLESS we're going to a page
    class_option_names = [ :trigger, :submit, :preload ]
    attribute_names = [ :id, :class, :style, :data, :onclick, :onload, :method, :rel, :title ]
    # We do NOT want a remote response: it asks for Javascript
    options = options.clone
    handler_class = options.delete(:handler_class) || 'submit'
    options.delete :remote

    # Pull out button options and set classes appropriately to express the link as a button
    bootstrap_button_options options

    query = options.delete(:query) || {} # Remove the query options from consideration and include them in the path
    format = options.delete(:format) || :json # Submitting for JSON unless otherwise stipulated

    if format == :html
      options.delete :mode # Page is assumed in an HTML response
    else
      # These options get included in the link's class
      # Pull out all class options and assert class "submit" to attract Javascript handling
      class_list = [ handler_class ]
      if class_options = options.slice(*class_option_names)
        class_list += class_options.keep_if { |k, v| v }.keys
      end
      class_str = (options[:class] || '').assert_words class_list
      options[:class] = class_str unless class_str.blank?

      # Include the query options in the path's query

      query.merge! options.slice(*query_option_names)
    end
    linkpath = assert_query url_for(path_or_options), format, query

    options.except! *(class_option_names+query_option_names)
    # Now the options have had the class options and query options removed.
    # The remaining options--except for those to be passed to link_to--will be merged into the data

    # Sequester all options except HTML standard link options in the data attribute
    link_options = options.slice *attribute_names
    link_options[:title] ||= "Your Tooltip Here"
    data = (options[:data] ||= {}).merge options.except(*attribute_names)
    data.keys.each do |key|
      # data with keys of the form 'data-.*' get folded in directly
      if match = key.to_s.match(/^data-(.*$)/)
        data[match[1]] = data.delete key
      end
    end
    if format == :html
      link_options[:data] = data unless data.empty?
      link_options[:path] = linkpath
    else
      data[:href] = linkpath
      link_options[:data] = data
      link_options[:path] = 'javascript:void(0);'
    end

    link_options
  end

  def linkpath object, action=nil
    (action && polymorphic_path([action, object]) rescue nil) ||
        (polymorphic_path([:collection, object]) rescue nil) ||
        (polymorphic_path([:contents, object]) rescue nil) ||
        (polymorphic_path([:associated, object]) rescue nil) ||
        polymorphic_path(object)
  end

  # Provide an internal link to an object's #associated, #contents or #show methods, as available
  def homelink decorator, options={}
    decorator = decorator.decorate unless decorator.is_a?(Draper::Decorator)
    data = options[:data] || {}
    data[:report] = (polymorphic_path([:touch, decorator.object]) rescue nil)

    cssclass = "#{options[:class]} entity #{decorator.object.class.to_s.underscore}"

    amended_options = {mode: :partial}.
        merge(options).
        merge(data: (data unless data.compact.empty?), class: cssclass).
        except(:action, :truncate).
        compact

    title = options[:title] || decorator.title
    if options[:truncate]
      title = title.truncate(options[:truncate])
    end

    link = link_to_submit title, linkpath(decorator.object, options[:action]), amended_options
    if decorator.respond_to?(:external_link)
      link << '&nbsp;'.html_safe + link_to('',
                                          decorator.external_link,
                                          class: 'glyphicon glyphicon-play-circle',
                                          style: 'color: #aaa',
                                          :target => '_blank')
    end
    link
  end
end
