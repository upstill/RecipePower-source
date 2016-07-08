module QueryHelper

  # Define a query item using a tagging interface
  def token_input_query opt_param={}
    options = opt_param.dup
    data = options.slice :hint, :placeholder, :'no-results-text', :"min-chars"

    # Assert defaults for data fields
    data[:hint] ||= 'Narrow down the list'
    data[:placeholder] ||= 'Seek and ye shall find...'
    data[:'min-chars'] ||= 2
    data[:'no-results-text'] ||= 'No matching tag found; hit Enter to search with text'
    # JS for how to invoke the search on tag completion:
    # querify (tagger.js) for standard tag handling;
    # submit (tagger.js) for results enclosures (which maintain and accumulate query data)
    data[:'on-add'] = options[:handler] || 'submit'
    data[:'on-delete'] = options[:handler] || 'submit'

    # Set up the tokeninput data
    querytags = options[:querytags] || []
    tagtype = options[:tagtype]

    data[:query] = "tagtype=#{tagtype}" if tagtype
    data[:pre] = querytags.collect { |tag| {id: tag.id, name: tag.name} }.to_json
    options[:onload] = 'RP.tagger.onload(event);'
    options[:class] = "token-input-field-pending #{options[:class]}" # The token-input-field-pending class triggers tokenInput

    options[:rows] ||= 1
    options[:autofocus] = true unless options[:autofocus] == false
    qt = text_field_tag 'querytags',
                        querytags.map(&:id).join(','),
                        options.except(:handler, :querytags, :tagtype, :type_selector).merge(data: data)
    qt += content_tag(:div,
                      content_tag(:span, '', class: "glyphicon glyphicon-#{options[:glyphicon]}"),
                      class: 'search-glyph'
    ) if options[:glyphicon]

    if options[:type_selector]
      type_select = 'Show tags of type&nbsp;'.html_safe +
          select_tag(:tagtype,
                     options_from_collection_for_select(Tag.type_selections(true, true), :last, :first, options[:tagtype]) || 0,
                     :include_blank => false,
                     :onchange => 'RP.tagger.select_type(event);')  # RP.submit.onselect( event );') +
      batch_select = options[:batch_select] ? ('  ...from batch #&nbsp;'.html_safe +
          select_tag(:batch, options_for_select((1..(options[:batch_select].to_i)).to_a, options[:batch]),
                     :include_blank => true,
                     :onchange => 'RP.tagger.select_batch( event );')) : ''.html_safe

      content_tag :div, type_select+batch_select,
              style: 'display:inline-block; vertical-align:bottom; margin:5px 10px'
    else
      ''.html_safe
    end +
        content_tag(:div, qt, class: 'token-input-elmt')
  end
end
