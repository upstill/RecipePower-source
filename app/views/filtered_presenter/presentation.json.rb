{
    replacements: [
        pagelet_filter_replacement(@filtered_presenter.global_querytags),
        pagelet_body_replacement('filtered_presenter/presentation') ]
}.merge(flash_notify).to_json