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
end
