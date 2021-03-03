{
  replacements: [
      recipe_content_replacement(@recipe)
  ],
  dlog: with_format('html') {
    do_recipe_contents_panel @form_title.if_present || 'Replacement Annotator', @form_name
  }
}.merge(flash_notify).to_json
