module PageRefsHelper

  # Show a reference, using as text the name of the related site
  def present_page_ref page_ref, options={}
    ref_link = (ref_name = page_ref.title).present? ?
        link_to(ref_name, page_ref.url, :target => '_blank', class: 'page') :
        "".html_safe
    if site = page_ref.site
      ref_link << ' on '.html_safe unless ref_link.blank?
      ref_link << link_to(site.name, site.home, :target => '_blank', class: 'site')
    end
    if options[:label].present?
      "#{options[:label]}: ".html_safe + ref_link
    else
      ref_link
    end
  end

  def page_ref_identifier pr, label=nil
    label = 'Page' unless label.present?
    "#{label} (##{pr.id}): ".html_safe +
        homelink(pr.decorate, nuke_button: !(pr.recipe? || pr.site?))
  end

end
