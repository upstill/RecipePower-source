module StreamHelper

  def stream_table headers
    render "shared/stream_results_table", headers: headers
  end

  def stream_element_class etype
    "stream-#{etype}"
  end

  # Use a partial to generate a stream header, and surround it with a 'stream-header' div
  def stream_element etype, partial=nil, locals={}
    if partial.is_a? Hash
      partial, locals = nil, partial
    end
    # Define a default partial as needed
    unless partial || block_given?
      if etype == :results
        partial = @sp.results_partial
      else
        fname = etype.to_s.sub /-/, '_'
        partial = "shared/stream_#{fname}"
      end
    end
    if partial
      renderparms = { partial: partial, locals: locals }
      content = render renderparms
    elsif block_given? # If no headerpartial provided, expect there to be a code block to produce the content
      content = yield
    end
    stream_element_package etype, content
  end

  def stream_element_package etype, content
    tag =
        case etype.to_s
          when "count"
            :span
          when /^nav/
            :nav
          else
            :div
        end
    # We automatically include an empty trigger at the end of results, for later replacement in streaming
    # content << content_tag(:span, "", class: "stream-trigger") if etype==:results
    content_tag tag, content, class: stream_element_class(etype)
  end

  # This is kind of a cheater helper, to render a template for embedding in a replacement
  def render_template controller, action
    render template: "#{controller}/#{action}", layout: false, formats: [:html]
  end

  # Generate a JSON item for replacing the stream header
  def stream_element_replacement etype, headerpartial=nil, locals={}
    if headerpartial.is_a? Hash
      headerpartial, locals = nil, headerpartial
    end
    content = block_given? ?
      stream_element( etype, headerpartial, locals) { yield } :
      stream_element(etype, headerpartial, locals)
    replacement = ["."+stream_element_class(etype), content ]
    replacement << "RP.stream.check" if etype==:trigger
    replacement
  end

  def stream_count force=false
    if @sp.has_query? && (@sp.ready? || force)
      case nmatches = @sp.nmatches
        when 0
          "No matches found"
        when 1
          "1 match found"
        else
          "#{nmatches} found"
      end
    else
      case nmatches = @sp.full_size
        when 0
          "Regrettably empty"
        when 1
          "Only one here"
        else
          "#{nmatches} altogether"
      end
    end
  end

  # A useful starting point for a pagelet, with just a searchable header and search results
  def simple_pagelet locals={}
    locals[:title] ||= response_service.title
    stream_element :body, "shared/simple_pagelet", locals
  end

  # Provide a tokeninput field for specifying tags, with or without the ability to free-tag
  # The options are those of the tokeninput plugin, with defaults
  def stream_filter_field presenter, options={}
    data = options[:data] || {}
    data[:hint] ||= "Narrow down the list"
    data[:pre] ||= @querytags.map(&:attributes).collect { |attr| { id: attr["id"], name: attr["name"] } }.to_json
    data[:"min-chars"] ||= 2
    data[:query] = "tagtype=#{presenter.tagtype}" if presenter.tagtype

    options[:class] = "token-input-field-pending #{options[:class]}" # The token-input-field-pending class triggers tokenInput
    options[:onload] = "RP.tagger.onload(event);"
    options[:data] = data

    text_field_tag "querytags", @querytags.map(&:id).join(','), options
  end

  # Render an element of a collection, depending on its class
  # NB The view is derived from the class of the element, NOT from the current controller
  def render_stream_item element, partialname=nil
    partialname ||= @sp.item_partial || "show_masonry_item"
    # Get the item-rendering partial from the model view
    unless partialname.match /\//
      # Use a partial specific to the entity if the file exists
      dir = element.class.to_s.underscore.pluralize
      partialname = "#{dir}/#{partialname}" if File.exists?(Rails.root.join("app", "views", dir, "_#{partialname}.html.erb"))
    end
    render partial: partialname, locals: { :item => controller.update_and_decorate(element) }
  end

  def render_stream_tail
    render partial: @sp.tail_partial
  end

  # Kind of redundant, since it just calls the like-named partial, but at least it obviates probs. with render_to_string
  def stream_results_placeholder
    with_format("html") { render partial: "shared/stream_results_placeholder" }
  end

end
