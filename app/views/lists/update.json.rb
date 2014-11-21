{
    done: true,
    replacements: [
        [ "#list"+@list.id.to_s, with_format("html") { render_to_string partial: "lists/index_table_row", locals: { item: @list }} ],
        navtab_replacement(:lists)
    ],
}.merge(flash_notify).to_json