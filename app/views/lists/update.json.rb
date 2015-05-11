{
    done: true,
    followup: pagelet_followup(@decorator),
    replacements: [
        # [ "#list"+@list.id.to_s, with_format("html") { render "lists/show_table_item", locals: { item: @list }} ],
        navtab_replacement(:my_lists),
        navtab_replacement(:other_lists)
    ],
}.merge(flash_notify).to_json
