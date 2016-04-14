{
    replacements: [
      gleaning_field_replacement(@entity_decorator, @finder.label)
    ]
}.merge(flash_notify).to_json
