{
    replacements: [
        [ 'div.card-item', '<div class="card-item"></div>' ],
        recipe_page_replacement(@recipe_page)
    ],
}.merge(flash_notify).to_json
