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

  def summarize_page_ref pr, options={}
    separator = summary_separator options[:separator]
    header = '' #, inward_separator = '', summary_separator(separator)
    if options[:header] || options[:label]
      header = "#{options[:label] || 'Page'} (##{pr.id}): ".html_safe +
          homelink(pr.decorate, nuke_button: !(pr.recipe? || pr.site?))
    end
    referent_summaries = (pr.is_a?(Referrable) ? pr.referents.limit(8) : []).collect { |referent|
      summarize_referent referent, label: "#{referent.class} ##{referent.id}", separator: separator
    }
    summarize_set '', [header] + referent_summaries, separator
  end

end
