module QuerifyHelper

  # Declare a querify supervisor element that manages the given url but
  # potentially has its own bailiwick (e.g., a results panel imposing a type)
  def querify_supe url, options={}, &block
    body_content = with_output_buffer &block
    content_tag (options[:tag] || :div),
                body_content,
                data: analyze_request(url),
                onload: 'RP.querify.onload(event);',
                class: "#{options[:class]} querify-supe"
  end

end