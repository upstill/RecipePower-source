{
    done: true,
    replacements: [
        [ "#list"+@list.id.to_s, with_format("html") { render "lists/index_table_row", locals: { item: @list }} ],
        navtab_replacement(:my_lists)
    ],
}.merge(flash_notify).to_json