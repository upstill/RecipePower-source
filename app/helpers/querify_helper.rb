module QuerifyHelper

  # A querify_block defines a context for querify actions
  # -- it takes querify params from enclosing blocks AND from enclosed buttons
  # -- IF it has an associated URL, it executes upon loading and upon receipt of other params
  # -- it broadcasts any param changes to other, lower querify blocks and links
  def querify_block url, options={}, &block
    if url.is_a? Hash
      url, options = nil, url
    end
    tag = options.delete(:tag) || :div
    options = options.merge class: "#{options[:class]} querify querify-supe #{'querify-exec' if url}"
    options.merge!( data: { href: url }) if url
    options[:onload] = 'RP.querify.onload(event);' if options.delete(:autoload)
    body_content = with_output_buffer &block
    content_tag tag, body_content, options
  end

  # Declare a link which records param changes and maintains a clickable link influenced by those params
  def querify_link label, url, options={}
    link_to_submit label,
                   url,
                   options.merge( class: "#{options[:class]} querify-link" )
  end

  # Declare a button which propagates parameter changes to enclosing querify supes
  def querify_button name, value, options={}
    button_tag(type: "querify",
               class: "#{options[:class]} querify",
               onclick: "RP.querify.onclick(event);", # Send when clicked
               name: name,
               value: value) do
      yield if block_given?
    end
  end

end
