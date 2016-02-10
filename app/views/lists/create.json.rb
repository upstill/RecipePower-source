{
  done: true,
  dlog: with_format('html') { render 'tag_modal' },
  replacements: [
     navmenu_replacement(:my_lists)
  ]
}.merge(flash_notify).to_json