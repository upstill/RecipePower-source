module TaggableHelper
  
  # Generalization of taggable_field for arbitrary attribute names (not just 'tags'--the default), and allowing
  #   for both form_for and simple_form fields as well as for raw objects

  def token_input_field f, tags_attribute_name=nil, options={}
    if tags_attribute_name.is_a? Hash
      tags_attribute_name, options = nil, tags_attribute_name
    end
    tags_attribute_name ||= 'editable_tags' # Assert the default
    attribute_name = tags_attribute_name.to_s.singularize
    is_plural = attribute_name != tags_attribute_name.to_s
    attribute_name << '_tag' unless attribute_name.match /tag$/
    field_name = attribute_name + '_token'
    if is_plural
      attribute_name = attribute_name.pluralize
      field_name = field_name.pluralize
    end
    # Label may be specified in :label option; if blank, use no label
    if options[:label]
      options[:label] = false if options[:label].blank?
    else
      options[:label] ||= attribute_name.tr('_', ' ').capitalize
    end

    object = (f.class.to_s.match /FormBuilder/) ? f.object : f
    options[:data] ||= {}
    options[:data][:hint] ||= "Type your tag(s) for the #{object.class.to_s.downcase} here"
    initrs = options[:attrval] || object.send(attribute_name)
    initrs = initrs.to_a if initrs.is_a? ActiveRecord::Relation
    initrs = [initrs] unless initrs.is_a? Array # Could be singular record, but #map expects an array
    options[:data][:pre] ||= initrs.compact.map(&:attributes).to_json
    options[:data][:token_limit] = 1 unless is_plural
    options[:data][:'min-chars'] ||= 2
    if type = options[:data][:type] || options[:data][:type_x]
      type = Tag.typenum type.is_a?(Array) ? type : [type]
      options[:data][:query] = "#{options[:data][:type] ? 'tagtype' : 'tagtype_x'}=#{type.map(&:to_s).join(',')}"
    end
    options[:class] = "token-input-field-pending #{options[:class]}" # The token-input-field-pending class triggers tokenInput
    options[:onload] = 'RP.tagger.onload(event);'
    if f==object # Not in the context of a form
      text_field_name = attribute_name+'txt'
      text_field_tag text_field_name, "#{object.send(text_field_name)}", options
    elsif f.class.to_s.match /SimpleForm/
      options[:input_html] ||= {}
      # Pass the :data, :onload and :class options to the input field via input_html
      options[:input_html].merge! options.slice(:data, :class, :onload)
      f.input field_name, options.slice!(:data, :class, :onload)
    else
      options[:html_options] = options.slice :class, :onload
      label_if_any = options[:label] ? f.label(field_name.to_sym, options[:label]) : ""
      label_if_any + f.text_field(field_name, options)
    end
  end

  def taggable_div(f, classname='edit_recipe_field', options={})
    if classname.is_a? Hash
      classname, options = 'edit_recipe_field', classname
    end
    options[:rows] ||= '1'
    options[:label] ||= 'Tags'
    content_tag :div, 
      token_input_field( f, options.delete(:attribute_name), options),
      { class: classname+' tags' },
      false
  end

  # OBSOLETE: replaced by decorator.extract('tags')
  def taggable_list taggable, with_type=false
    taggable.tags.collect { |tag| "<span>#{tag.typedname(with_type)}</span>" }.join('<br>').html_safe
  end
	
end
