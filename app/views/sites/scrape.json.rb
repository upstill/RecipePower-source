# Present a dialog for choosing from some candidate feeds
{
    dlog: with_format("html") { render "scrape_modal" }
}.merge(flash_notify).to_json
