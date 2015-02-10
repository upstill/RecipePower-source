{
  done: true,
  dlog: with_format('html') { render "tag_modal" },
  replacements: [
     navtab_replacement(:my_lists)
  ]
}.merge(flash_notify).to_json