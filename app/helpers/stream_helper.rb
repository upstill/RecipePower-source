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
      content = render partial: partial, locals: locals
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
=begin
  # This generates an item for initializing the results stream by replacing the results element with its
  # display shell
  def stream_results_item headerpartial
    data = ActiveSupport::JSON.decode with_format("json") { render partial: headerpartial }
    { replacements: data }
  end

  def masonry_results_replacement
    stream_element_replacement(:results, "shared/stream_results_masonry") << "RP.masonry.onload"
  end

  def pagelet_body
    if body_partial.is_a? Hash
      locals, body_partial = body_partial, nil
    end
    stream_element :body, (body_partial || "#{response_service.action}_pagelet"), locals
  end

  # Return a JSON string passed to the client, for modifying the page of a stream
  def pagelet_body_replacement body_partial=nil, locals={}
    if body_partial.is_a? Hash
      locals, body_partial = body_partial, nil
    end
    body_partial ||= "#{response_service.action}_pagelet"
    default = {
        pushState: [ response_service.originator, response_service.page_title ],
        replacements:
            [
                stream_element_replacement(:body, body_partial, locals),
            ]
    }
    if block_given?
      extras = yield
      default[:replacements] = default[:replacements] + extras.delete(:replacements) if extras[:replacements]
      default.merge! extras
    end
    default.to_json
  end
=end

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
      dir = element.class.to_s.pluralize.sub(/([a-z])([A-Z])/, '\1_\2').downcase
      partialname = "#{dir}/#{partialname}"
    end
    render partial: partialname, locals: { :item => element }
  end

  def render_stream_tail
    render partial: @sp.tail_partial
  end

  def stream_results_placeholder
    content_tag :div,
                stream_element(:tail),
                class: "stream-results"
  end

end
