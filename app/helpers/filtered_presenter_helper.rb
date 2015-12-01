module FilteredPresenterHelper
  def filtered_presenter_org_buttons viewparams, label=nil, options={}
    if label.is_a? Hash
      label, options = nil, label
    end
    buttons = (label || '').html_safe
    viewparams.org_buttons do |label, link=nil, link_options = {}|
      link, link_options = nil, link if link.is_a? Hash
      link_options[:class] = (link_options[:class] || '') +
          "#{'disabled' unless link} panels-button soft-button #{viewparams.display_style}-button #{options[:class]}"
      buttons << querify_link( label.upcase, link||'#', link_options )
    end
    content_tag :div, buttons, class: 'panels-buttons'
  end

  def filtered_presenter_org_buttons_replacement viewparams
    [ 'div.panels-buttons', filtered_presenter_org_buttons(viewparams, 'order by', class: 'small') ]
  end

end
