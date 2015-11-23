module FilteredPresenterHelper
  def filtered_presenter_header_buttons fp
    buttons = ''.html_safe
    fp.header_buttons do |label, link=nil, link_options = {}|
      link, link_options = nil, link if link.is_a? Hash
      link_options[:class] = (link_options[:class] || '') +
          "#{'disabled' unless link} panels-button soft-button #{fp.viewparams.display_style}-button"
      buttons << querify_link( label.upcase, link||'#', link_options )
    end
    content_tag :div, buttons, class: 'panels-buttons'
  end

end