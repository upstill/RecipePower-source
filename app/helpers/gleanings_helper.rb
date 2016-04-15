module GleaningsHelper

  def gleaning_field decorator, label
    entity_name = decorator.object.class.to_s.underscore
    options = decorator.gleaning.options_for label
    select_tag "#{entity_name}[gleaning_attributes][#{label}]",
               options_for_select(options),
               prompt: "Gleaned #{(options.count > 1) ? label.pluralize : label}",
               class: 'gleaning-select',
               id: label
  end

  def gleaning_field_replacement decorator, label
    ["select##{label}", gleaning_field(decorator, label) ]
  end
end
