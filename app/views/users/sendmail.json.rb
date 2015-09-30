{
  dlog: with_format("html") { render "sendmail_modal" }
}.merge(flash_notify).to_json
