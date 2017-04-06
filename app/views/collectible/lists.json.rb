{
    # dlog: with_format("html") { render response_service.select_render('lists') }
replacements: [
    [ 'div#lists-collectible-suggested',
      with_format("html") { render 'lists_collectible_suggested', decorator: @decorator }
    ]
]
}.merge(flash_notify).to_json
