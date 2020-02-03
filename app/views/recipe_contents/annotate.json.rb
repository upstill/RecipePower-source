{
  replacements: [
      recipe_content_replacement(@recipe),
  ],
  dlog: with_format('html') {
    do_recipe_pages_panel 'Replacement Annotator', :recipe_contents
  }
}.merge(flash_notify).to_json
