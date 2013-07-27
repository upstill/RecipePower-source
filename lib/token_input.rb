# SimpleForm (https://github.com/plataformatec/simple_form)
# jQuery Tokenninput (http://loopj.com/jquery-tokeninput/)
class TokenInput < SimpleForm::Inputs::Base
  def input
    input_html_options[:"data-url"] = "/#{reflection.klass.name.tableize}.json"
    if @builder.object.send(reflection.name).nil?
      if input_html_options[:value]
        object = reflection.klass.find(input_html_options[:value])
      end
    else
      object = @builder.object.send(reflection.name)
    end
    input_html_options[:"data-pre"] = "[#{object.to_json(:only => [:id, :name])}]" if object
    "#{@builder.text_field(attribute_name, input_html_options)}".html_safe
  end

  # An iterator over the elements of a token string, calling the block
  # on either an integer key, or a string.
  def self.parse_tokens(idstring)
    # The list may contain new terms, passed in single quotes
    idstring.split(",").map { |e| 
      e = (e=~/^\d*$/) ? 
        e.to_i : # numbers (sans quotes) represent existing tags
        e.sub(/^\'(.*)\'$/, '\1') # Strip out enclosing quotes
      block_given? ? yield(e) : e
    }.compact.uniq
  end

end
