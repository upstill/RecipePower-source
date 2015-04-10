module QueryHelper

  # Define a query item using a tagging interface
  def token_input_query options={}
    querytags = []
    tagtype = nil # stream_presenter.tagtype
    data = options[:data] || {}
    data[:hint] ||= "Narrow down the list"
    data[:pre] ||= querytags.collect { |tag| {id: tag.id, name: tag.name} }.to_json
    data[:"min-chars"] ||= 2
    data[:query] = "tagtype=#{tagtype}" if tagtype

    options[:class] = "token-input-field-pending #{options[:class]}" # The token-input-field-pending class triggers tokenInput
    options[:onload] = "RP.tagger.onload(event);"
    options[:data] = data

    text_field_tag "querytags", querytags.map(&:id).join(','), options
  end
end
