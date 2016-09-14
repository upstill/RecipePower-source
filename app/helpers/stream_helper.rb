module StreamHelper

  def stream_loadlink next_path, container_selector, check_fcn = nil
    data = { path: next_path }
    data[:'trigger-check'] = check_fcn if check_fcn
    link_to 'Click to load', '#',
            onclick: 'RP.stream.go(event);',
            onload: 'RP.stream.onload(event);',
            class: 'stream-trigger',
            # style: 'display: none;', for the use of jQuery.show()
            data: data
  end

  def stream_element_class etype
    "stream-#{etype} #{response_service.controller}-#{response_service.action}"
  end

  def stream_element_selector etype
    ".stream-#{etype}"
  end

  # Use a partial to generate a stream header, and surround it with a 'stream-header' div
  def stream_element etype, partial=nil, locals={}
    if partial.is_a? Hash
      partial, locals = nil, partial
    end
    # Define a default partial as needed
    unless partial || block_given?
      fname = etype.to_s.gsub /-/, '_'
      partial = "shared/stream_#{fname}"
    end
    if partial
      renderparms = { partial: partial, locals: locals }
      content = render renderparms
    elsif block_given? # If no headerpartial provided, expect there to be a code block to produce the content
      content = yield
    end
    stream_element_package etype, content, locals[:pkg_attributes]
  end

  def stream_element_package etype, content, pkg_attributes=nil
    pkg_attributes ||= {}
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
    pkg_attributes[:class] = stream_element_class(etype)
    content_tag tag, content, pkg_attributes
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
      stream_element( etype, headerpartial, locals)
    replacement = [ stream_element_selector(etype), content ]
    replacement << "RP.stream.check" if etype==:trigger
    replacement
  end

  # A useful starting point for a pagelet, with just a searchable header and search results
  def simple_pagelet locals={}
    locals[:title] ||= response_service.title
    stream_element :body, "shared/simple_pagelet", locals
  end

end
