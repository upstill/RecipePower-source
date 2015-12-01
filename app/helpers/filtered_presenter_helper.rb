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
          "#{'disabled' unless link} org-button soft-button #{viewparams.display_style} #{options[:class]}"
      buttons << querify_link( label.upcase, link||'#', link_options )
    end || ''
    content_tag :div, label.html_safe+buttons, class: "org-buttons #{context}-buttons"
  end

  def filtered_presenter_org_buttons_replacement viewparams, context='panels'
    [ "div.org-buttons.#{context}-buttons", filtered_presenter_org_buttons(viewparams, context) ]
  end

end
