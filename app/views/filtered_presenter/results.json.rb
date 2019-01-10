viewparams = @viewparams || (@filtered_presenter && @filtered_presenter.viewparams) unless defined?(viewparams) && viewparams 
result_type = viewparams.result_type
{
    replacements: [
        # filtered_presenter_org_buttons_replacement(viewparams, 'panels'),
        # filtered_presenter_org_buttons_replacement(viewparams, 'header'),
        panel_collapse_button_replacement(result_type, viewparams.item_mode),
        # panel_org_menu_replacement(viewparams.request_path, result_type, viewparams.org),
        # panel_suggestion_button_replacement(viewparams.request_path, result_type),
        # filtered_presenter_header_label_replacement(viewparams),
        filtered_presenter_panel_results_replacement(viewparams),
        panel_suggestions_replacement(result_type)
    ].compact
}.to_json
