module TaggableHelper
  
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

  # Generalization of taggable_field for arbitrary attribute names (not just 'tags'), and allowing
  #   for both form_for and simple_form fields as well as for raw objects
  # Convention MUST BE HONORED! For a tag attribute named 'tags':
  #   1) tags can be set by writing to 'tag_tokens'
  #   2) the text for the field can be read from and written to 'tagstxt'

  def token_input_field(f, attrname, options={})
    object = (f.class.to_s.match /FormBuilder/) ? f.object : f
    tags = object.read_attribute(attrname)
    options[:data] ||= {}
    options[:data][:hint] ||= "Type your tag(s) for the #{object.class.to_s.downcase} here"
    options[:data][:pre] = tags.map(&:attributes).to_json
    options[:class] = "token-input-field #{options[:class]}"
    if f==object # Not in the context of a form
      text_field_tag :"#{attrname}txt", "#{object.read_attribute("#{attrname}txt")}", options
    else
      f.text_field :"#{attrname.singularize}_tokens", options
    end
  end

  def taggable_div(f, classname="", label="Tags", options={})
    options[:rows] ||= "1"
    content_tag :div, 
      (label ? f.label(:tag_tokens, label) : "") + 
      taggable_field( f, options), 
      { class: classname+" tags" }, false
  end
  
  def taggable_list taggable
    taggable.tags.collect { |tag| "<span>#{tag.name}</span>" }.join('<br>').html_safe
  end
	
end