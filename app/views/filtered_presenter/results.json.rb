viewparams ||= @filtered_presenter.viewparams
result_type = viewparams.result_type
{
    replacements: [
        filtered_presenter_org_buttons_replacement(viewparams),
        panel_collapse_button_replacement(result_type, viewparams.item_mode),
        panel_org_menu_replacement(viewparams.request_path, result_type, viewparams.org),
        panel_suggestion_button_replacement(viewparams.request_path, result_type),
        panel_results_replacement(result_type, viewparams.results_partial),
        panel_suggestions_replacement(result_type)
    ]
}.to_json
