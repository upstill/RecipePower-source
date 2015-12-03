module FilteredPresenterHelper
  def filtered_presenter_org_buttons viewparams, context='panels', options={}
    if context.is_a? Hash
      context, options = 'panels', context
    end
    buttons = ''.html_safe
    label =
    viewparams.org_buttons(context) do |label, link=nil, link_options = {}|
      link, link_options = nil, link if link.is_a? Hash
      link_options[:class] = (link_options[:class] || '') +
          "#{'disabled' unless link} org-button soft-button #{viewparams.display_style false} #{options[:class]}"
      buttons << querify_link( label.upcase, link||'#', link_options )
    end || ''
    content_tag :div, label.html_safe+buttons, class: "org-buttons #{context}-buttons" if buttons.present?
  end

  def filtered_presenter_org_buttons_replacement viewparams, context='panels'
    [ "div.org-buttons.#{context}-buttons", filtered_presenter_org_buttons(viewparams, context) ]
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

  def filtered_presenter_tail viewparams
    render "filtered_presenter/present/#{viewparams.tail_partial}", viewparams: viewparams
  end
end