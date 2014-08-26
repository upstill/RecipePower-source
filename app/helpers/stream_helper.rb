module StreamHelper

  def stream_table headers
    render "shared/stream_results_table", headers: headers
  end

  def stream_element_class etype
    "stream-#{etype}"
  end

  # Use a partial to generate a stream header, and surround it with a 'stream-header' div
  def stream_element etype, headerpartial=nil, locals={}
    if headerpartial.is_a? Hash
      headerpartial, locals = nil, headerpartial
    end
    # Define a default partial as needed
    fname = etype.to_s.sub /-/, '_'
    headerpartial ||= "shared/stream_#{fname}" unless block_given?
    if headerpartial
      content = with_format("html") { render partial: headerpartial, locals: locals }
    else # If no headerpartial provided, expect there to be a code block to produce the content
      content = with_format("html") { yield }
    end
    tag =
        case etype.to_s
          when "count"
            :span
          when /^nav/
            :nav
          else
            :div
        end
    content_tag tag, content, class: stream_element_class(etype)
  end

  # Generate a JSON item for replacing the stream header
  def stream_element_replacement etype, headerpartial=nil, locals={}
    if headerpartial.is_a? Hash
      headerpartial, locals = nil, headerpartial
    end
    content = block_given? ?
      stream_element( etype, headerpartial) { yield } :
      stream_element(etype, headerpartial, locals)
    ["."+stream_element_class(etype), content ]
  end

  def masonry_results_replacement
    stream_element_replacement(:results, "shared/stream_results_masonry") << "RP.masonry.onload"
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
    options[:onload] = "RP.tagger.onload(evt);"
    options[:data] = data

    text_field_tag "querytags", @querytags.map(&:id).join(','), options
  end

  # Render an element of a collection, depending on its class
  # NB The view is derived from the class of the element, NOT from the current controller
  def render_stream_item element, partialname
    # Prepend the partialname with the view directory name if it doesn't already have one
    partialname = "#{element.class.to_s.pluralize.downcase}/#{partialname}" unless partialname.match /\//
    render partial: partialname, locals: { :item => element }
  end

end
