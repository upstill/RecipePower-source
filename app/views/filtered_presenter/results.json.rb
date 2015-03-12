{
    replacements: [
        [ "a.#{@master_presenter.results_cssclass}",
          with_format("html") { render @master_presenter.results_partial } ]
    ]
}.to_json