module QueryHelper

  # Define a query item using a tagging interface
  def token_input_query opt_param={}
    options = opt_param.dup
    data = options.slice :hint, :placeholder, :'no-results-text', :"min-chars"

    # Assert defaults for data fields
    data[:hint] ||= 'Narrow down the list'
    data[:placeholder] ||= "Seek and ye shall find..."
    data[:"min-chars"] ||= 2
    data[:"no-results-text"] ||= "No matching tag found; hit Enter to search with text"
    # JS for how to invoke the search on tag completion:
    # RP.tagger.querify for standard tag handling;
    # RP.submit.enclosing_form for results enclosures (which maintain and accumulate query data)
    data[:'on-add'] = options[:handler] || 'RP.submit.enclosing_form'
    data[:'on-delete'] = options[:handler] || 'RP.submit.enclosing_form'

    # Set up the tokeninput data
    querytags = options[:querytags] || []
    tagtype = options[:tagtype]

    data[:query] = "tagtype=#{tagtype}" if tagtype
    data[:pre] = querytags.collect { |tag| {id: tag.id, name: tag.name} }.to_json
    options[:onload] = "RP.tagger.onload(event);"
    options[:class] = "token-input-field-pending #{options[:class]}" # The token-input-field-pending class triggers tokenInput

    options[:rows] ||= 1
    options[:autofocus] = true unless options[:autofocus] == false

    if options[:type_selector]
      content_tag :div,
                  select_tag(:tagtype,
                             options_from_collection_for_select(Tag.type_selections(true, true), :last, :first, options[:tagtype]) || 0,
                             :include_blank => false,
                             :onchange => 'RP.tagger.select_type(event);'), # RP.submit.onselect( event );'),
                  style: 'display:inline-block; vertical-align:bottom; margin:5px 10px'
    else
      ''.html_safe
    end +
        content_tag(:div,
                    text_field_tag("querytags",
                                   querytags.map(&:id).join(','),
                                   options.except(:handler, :querytags, :tagtype, :type_selector).merge(data: data)),
                    style: 'display: inline-block; width:300px;')
  end
end
