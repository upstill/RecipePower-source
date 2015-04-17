type = @filtered_presenter.results_cssclass
item_mode = @filtered_presenter.item_mode
{
    replacements: [
        panel_collapse_button_replacement(type, item_mode),
        panel_org_menu_replacement(@filtered_presenter.this_path, type, @filtered_presenter.org),
        panel_suggestion_button_replacement(@filtered_presenter.this_path, type),
        panel_results_replacement(type, @filtered_presenter.results_partial),
        panel_suggestions_replacement(type)
    ]
}.to_json
