{
    done: true,
    followup: { request: list_url(@list, :mode => :partial, :nocache => true ), target: "div.pagelet-body#"+pagelet_body_id(@list) },
    replacements: [
        # [ "#list"+@list.id.to_s, with_format("html") { render "lists/index_table_row", locals: { item: @list }} ],
        navtab_replacement(:my_lists),
        navtab_replacement(:other_lists)
    ],
}.merge(flash_notify).to_json