{
  replacements: [
      recipe_content_replacement(@recipe)
  ],
  dlog: with_format('html') {
    do_recipe_contents_panel 'Replacement Annotator'
  }
}.merge(flash_notify).to_json
