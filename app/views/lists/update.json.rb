{
    done: true,
    followup: pagelet_followup(@decorator),
    replacements: [
        item_replacement(@decorator, :table),
        navmenu_replacement(:my_lists),
        navmenu_replacement(:other_lists)
    ],
}.merge(flash_notify).to_json
