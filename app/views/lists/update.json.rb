{
    done: true,
    followup: pagelet_followup(@decorator),
    replacements: [
        item_replacement(@decorator, :table),
        navtab_replacement(:my_lists),
        navtab_replacement(:other_lists)
    ],
}.merge(flash_notify).to_json
