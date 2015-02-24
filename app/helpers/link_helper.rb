module LinkHelper

  # A wrapper for flavored_link which asserts button options for Bootstrap
  def button_to_submit label, path_or_options, kind="default", size="small", options={}
    if kind.kind_of? Hash
      kind, size, options = :default, :small, kind
    elsif size.kind_of? Hash
      size, options = :small, size
    end
    options = options.clone
    class_str = (options[:class] || "").gsub(/btn[-\w]*/i, '') # Purge the class of existing button classes
    options[:class] =  class_str.assert_words %W{ btn btn-#{kind} btn-#{size} }
    link_to_submit label, path_or_options, options
  end

  # Hit a URL using the RP.submit javascript module, with options for confirmation (:confirm-msg) and waiting (:wait-msg)
  # NB: options are used as follows:
  # mode can be one of:
  #  == :page to deploy a standard link
  #  == :modal to fetch a dialog via JSON
  #  == :partial to get a container via JSON
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
    format = :json
    mode = options[:mode]
    if mode == :page
      options.delete :mode # Page is assumed in an HTML response
      # The page is not interested in any class options or query options special to submit()
      format = nil # default is :html
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
    link_options[:data] = data unless data.empty?

    # if options[:method] && (options[:method].to_s != "get") # Other submit methods require a verified form
      # button_to label, linkpath, link_options
    # else
      link_to label, linkpath, link_options
    # end

  end

end
