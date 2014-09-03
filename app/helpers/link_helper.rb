module LinkHelper

  # Set up a remote interaction via the submit javascript module
  # TODO This method is almost certainly redundant and incorrect, since it uses :remote processing
  def button_to_submit label, url, options={}
    options[:class] = merge_word_strings options[:class], "btn btn-default btn-xs submit"
    options.merge! remote: true
    if options.delete :button_to
      button_to label, url, options
    else
      link_to label, url, options
    end
  end

  # Generalization of link_to to handle page, dialog and general submission requests
  def flavored_link label, path_or_options, as=:submit, options={}
    if path_or_options.blank?
      link_to_nowhere label, options
    else
      case as
        when :page
          link_to_page label, path_or_options, options
        when :dialog
          options = options.clone
          (options[:query] ||= {})[:modal] = true
          link_to_submit label, path_or_options, options
        else # Default: submit a JSON request for page-modifying data
          options = options.clone
          (options[:query] ||= {})[:partial] = true
          link_to_submit label, path_or_options, options
      end
    end
  end

  def link_to_nowhere label, options={}
    link_to label, "#", fix_options_for_link(options)
  end

  # Just a shortcut for flavored_link(... :dialog)
  def link_to_modal label, path_or_object, options={}
    options = options.clone
    (options[:query] ||= {})[:modal] = true
    link_to_submit label, path_or_object, options

    # path = url_for(path_or_object)
    # options[:class] = "dialog-run #{options[:class]}"
    # query_options = options[:query] || {}
    # path = assert_query path, query_options.merge(modal: true)
    # link_to label, path, options
  end

  def link_to_page label, path_or_options, options={}
    # Interpret and revise the path according to the :query option
    options = options.clone
    linkpath = fix_path_for_query path_or_options, options.delete(:query)

    # Move all options not relevant to link_to into :data
    options = fix_options_for_link options

    link_to label, linkpath, options
  end

  # Hit a URL using the RP.submit javascript module, with options for confirmation (:confirm-msg) and waiting (:wait-msg)
  def link_to_submit(label, path_or_options, options={})
    # We do NOT want a remote response: it asks for Javascript
    options = options.clone
    options.delete :remote # unless options[:remote]

    # Include query option(s) in the path
    linkpath = fix_path_for_query path_or_options, options.delete(:query)

    options = fix_options_for_link options

    # Assert class "submit" to attract Javascript handling
    options[:class] = "submit #{options[:class]}"

    link_to label, linkpath, options
  end

  # A wrapper for flavored_link which asserts button options for Bootstrap
  def button_link label, path_or_options, as=:submit, kind="default", size="xs", options={}
    if as.kind_of? Hash
      options, as = as, :submit
    elsif kind.kind_of? Hash
      options, kind = kind, :default
    elsif size.kind_of? Hash
      options, size = size, :xs
    end
    options = options.clone
    options[:class] = "btn btn-#{kind} btn-#{size} #{options[:class]}"
    flavored_link label, path_or_options, as, options
  end

  # Move all options not specific to a link into data
  def fix_options_for_link options={}
    keys_for_link_to = [:id, :class, :style, :data, :onclick, :method]
    # Move options other than the above into :data
    out = options.clone
    data = out.slice! *keys_for_link_to
    (out[:data] ||= {}).merge! data unless data.empty?
    out
  end

  def fix_path_for_query path_or_options, query={}
    if query && !query.empty?
      assert_query url_for(path_or_options), query
    else
      path_or_options
    end
  end

end