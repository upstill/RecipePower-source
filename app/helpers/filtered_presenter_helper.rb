module FilteredPresenterHelper
  def filtered_presenter_org_buttons viewparams, context='panels', options={}
    if context.is_a? Hash
      context, options = 'panels', context
    end
    buttons = ''.html_safe
    label =
    viewparams.org_buttons(context) do |label, qparams, link_options = {}|
      link_options[:class] =
          "#{link_options[:class]} org-button #{viewparams.display_style} #{options[:class]}"
      buttons << querify_radiobutton( label.upcase.html_safe, qparams, link_options )
    end || ''
    buttons = content_tag :div, buttons, class: 'btn-group', data: { toggle: 'buttons' }
    content_tag :div,
                content_tag(:span, label, class: 'org-buttons-label')+buttons,
                class: "org-buttons #{viewparams.display_style} #{context}-buttons" if buttons.present?
  end

  def filtered_presenter_org_buttons_replacement viewparams, context='panels'
    [ "div.org-buttons.#{context}-buttons.#{viewparams.display_style}", filtered_presenter_org_buttons(viewparams, context) ]
  end

  def filtered_presenter_panel_results_placeholder type
    content_tag :div, '', class: "results #{type.to_s.extensions_to_classes} placeholder"
  end

  def filtered_presenter_panel_results viewparams
    with_format('html') { render "filtered_presenter/present/#{viewparams.results_partial}", viewparams: viewparams }
  end

  def filtered_presenter_panel_results_replacement viewparams
    selector = '.results'
    selector << '.' + viewparams.result_type.extensions_to_selector
    [selector, filtered_presenter_panel_results(viewparams) ]
  end

  def filtered_presenter_table_results_placeholder viewparams
    content_tag :tbody, '', class: "results #{viewparams.result_type} placeholder"
  end

  def filtered_presenter_table_results viewparams
    with_format('html') { render "filtered_presenter/present/#{viewparams.results_partial}", viewparams: viewparams }
  end

  def filtered_presenter_table_results_replacement viewparams
    selector = '.results'
    selector << '.' + viewparams.result_type.extensions_to_selector
    [selector, filtered_presenter_table_results(viewparams) ]
  end

  def filtered_presenter_tail viewparams
    render "filtered_presenter/present/#{viewparams.tail_partial}", viewparams: viewparams
  end
end
