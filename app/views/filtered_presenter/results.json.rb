{
    replacements: [
        [ "a.#{@filtered_presenter.results_cssclass}",
          with_format("html") { render @filtered_presenter.results_partial } ]
    ]
}.to_json
