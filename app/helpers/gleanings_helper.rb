module GleaningsHelper

  def gleaning_field decorator, label
    entity_name = decorator.object.class.to_s.underscore
    options = decorator.gleaning.options_for label
    entity_field = decorator.findermap[label].to_s
    entity_field_type = decorator.input_field_type(label)
    select_tag "#{entity_name}[gleaning_attributes][#{label}]",
               options_for_select(options),
               prompt: "Gleaned #{(options.count > 1) ? label.pluralize : label}",
               class: 'select-string',
               id: label,
               data: {target: "#{entity_field_type}##{entity_name}_#{entity_field}"}
  end

  def gleaning_field_replacement decorator, label
    ["select##{label}", gleaning_field(decorator, label) ]
  end
end
