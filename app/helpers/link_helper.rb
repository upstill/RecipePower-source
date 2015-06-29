module LinkHelper

  # A wrapper for flavored_link which asserts either 1) button options for Bootstrap, or 2) glyphs via sprites
  def button_to_submit label, path_or_options, kind="default", size=nil, options={}
    if kind.kind_of? Hash
      kind, size, options = :default, nil, kind
    elsif size.kind_of? Hash
      size, options = nil, size
    end
    options = options.clone
    class_str = (options[:class] || "").gsub(/btn[-\w]*/i, '') # Purge the class of existing button classes
    if kind.match /^glyph-/ # 'kind' starting with 'glyph' denotes sprite
      label = sprite_glyph (kind.to_s.sub /^glyph-/, ''), "inline", size
    else # Otherwise, we use a Bootstrap button
      class_str << " btn btn-#{kind}"
      class_str << " btn-#{size}" if size
    end
    link_to_submit label, path_or_options, options.merge(class: class_str)
  end

  # Hit a URL using the RP.submit javascript module, with options for confirmation (:confirm-msg) and waiting (:wait-msg)
  # NB: options are used as follows:
  # format may be stipulated as :html to get a normal link; otherwise, the link will submit for JSON
  # mode can be one of:
  #  == :modal to fetch a dialog via JSON
  #  == :injector to get a dialog for foreign sites via JSON
  # :template, :trigger, :submit, and :preload are classes on the link for triggering submit behavior
  # :id, :class, :style, :data, :onclick, :rel and :method are passed to link_to to create attributes
  # ...all other options get folded into the data attribute of the link
  def link_to_submit label, path_or_options, options={}
    query_option_names = [ :mode ] # These get folded into the query UNLESS we're going to a page
    class_option_names = [ :trigger, :submit, :preload ]
    attribute_names = [ :id, :class, :style, :data, :onclick, :method, :rel ]
    # We do NOT want a remote response: it asks for Javascript
    options = options.clone
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
      class_list = [:submit]
      if class_options = options.slice(*class_option_names)
        class_list += class_options.keep_if { |k, v| v }.keys
      end
      class_str = (options[:class] || "").assert_words class_list
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
    data = (options[:data] ||= {}).merge options.except(*attribute_names)
    data.keys.each do |key|
      # data with keys of the form 'data-.*' get folded in directly
      if match = key.to_s.match(/^data-(.*$)/)
        data[match[1]] = data.delete key
      end
    end
    if format == :html
      link_options[:data] = data unless data.empty?
      link_to label, linkpath, link_options
    else
      data[:href] = linkpath
      link_options[:data] = data
      link_to label, 'javascript:void(0);', link_options
    end
  end

end
