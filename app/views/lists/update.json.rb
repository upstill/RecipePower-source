{
    done: true,
    followup: { request: list_url(@list, :mode => :partial), target: "div.pagelet-body#"+pagelet_body_id(@list) },
    replacements: [
        # [ "#list"+@list.id.to_s, with_format("html") { render "lists/index_table_row", locals: { item: @list }} ],
        # pagelet_body_replacement(@list),
        navtab_replacement(:my_lists)
    ],
}.merge(flash_notify).to_json