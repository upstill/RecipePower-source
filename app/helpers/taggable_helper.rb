module TaggableHelper
  
=begin
  # Declare a tagging field, either within the context of a form, or as a vanilla text field
  def taggable_field(f, options={})
    object = (f.class.to_s.match /FormBuilder/) ? f.object : f
    options[:data] ||= {}
    options[:data][:hint] ||= "Type your tag(s) for the #{object.class.to_s.downcase} here"
    options[:data][:pre] = object.tags.map(&:attributes).to_json
    options[:class] = "token-input-field #{options[:class]}"
    if f==object # Not in the context of a form
      text_field_tag :tagstxt, "#{object.tagstxt}", options
    else
  		f.text_field :tag_tokens, options
		end
  end
=end

  # Generalization of taggable_field for arbitrary attribute names (not just 'tags'--the default), and allowing
  #   for both form_for and simple_form fields as well as for raw objects
  # Convention MUST BE HONORED! For a tag attribute named 'tag'('tags'):
  #   1) tags can be set by 'tag_token='('tag_tokens=') -- this is the name of the field
  #   2) the text for the field can be read from and written to 'tagtxt' ('tagstxt')

  def token_input_field f, tags_attribute_name="tags", options={}
    if tags_attribute_name.is_a? Hash
      options = tags_attribute_name
      tags_attribute_name = nil
    end
    aname = (tags_attribute_name || "tags").to_s
    tags_attribute_name = aname.singularize
    is_plural = tags_attribute_name != aname
    tags_input_field = tags_attribute_name+"_token"
    label = tags_attribute_name.capitalize
    unless tags_attribute_name == "tag"
      tags_attribute_name << "_tag"
      label << " Tag"
    end

    if is_plural
      tags_input_field << "s"
      tags_attribute_name << 's'
      label << 's'
    end
    options[:label] ||= label

    object = (f.class.to_s.match /FormBuilder/) ? f.object : f
    options[:data] ||= {}
    options[:data][:hint] ||= "Type your tag(s) for the #{object.class.to_s.downcase} here"
    options[:data][:pre] ||= (options[:attrval] || object.send(tags_attribute_name)).map(&:attributes).to_json
    options[:data][:token_limit] = 1 unless is_plural
    options[:class] = "token-input-field #{options[:class]}"
    if f==object # Not in the context of a form
      text_field_name = tags_attribute_name+"txt"
      text_field_tag text_field_name, "#{object.send(text_field_name)}", options
    elsif f.class.to_s.match /SimpleForm/
      options[:input_html] ||= {}
      # Pass the :data and :class options to the input field via input_html
      options[:input_html][:data] = options.delete :data
      options[:input_html][:class] = options.delete :class
      f.input tags_input_field, options
    else
      options[:html_options] = options.slice :class
      (label ? f.label(tags_input_field.to_sym, options[:label]) : "") +
      (f.text_field tags_input_field, options)
    end
  end

  def taggable_div(f, classname="", options={})
    options[:rows] ||= "1"
    content_tag :div, 
      token_input_field( f, options.delete(:attribute_name), options),
      { class: classname+" tags" },
      false
  end
  
  def taggable_list taggable
    taggable.tags.collect { |tag| "<span>#{tag.typedname}</span>" }.join('<br>').html_safe
  end
	
end