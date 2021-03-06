{
  replacements: [ recipe_content_replacement(@recipe) ],
  dlog: with_format('html') { render 'recipe_contents/edit_modal' }
}.merge(flash_notify).to_json
