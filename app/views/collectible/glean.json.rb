{
    replacements: [
            [ 'div.pic-pickees', with_format("html") { render partial: "pic_select_list", layout: false } ]
    ]
}.merge(flash_notify).to_json
