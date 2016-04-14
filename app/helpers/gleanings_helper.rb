module GleaningsHelper

  def gleaning_field entity, label, target_input_type=nil
    entity_name = entity.class.to_s.underscore
    options = entity.gleaning.options_for label
    entity_field = entity.decorate.findermap[label].to_s
    target_input_type ||=
        case entity.class.columns_hash[entity_field].type
          when :string
            'input'
          when :text
            'textarea'
        end
    select_tag "#{entity_name}[gleaning_attributes][#{label}]",
               options_for_select(options),
               prompt: "Gleaned #{(options.count > 1) ? label.pluralize : label}",
               class: 'select-string',
               id: label,
               data: {target: "#{target_input_type}##{entity_name}_#{entity_field}"}
  end

  def gleaning_field_replacement entity, label, target_input_type=nil
    ["select##{label}", gleaning_field(entity, label, target_input_type) ]
  end
end
