module PageRefsHelper

  # Show a reference, using as text the name of the related site
  def present_definition def_page_ref
    ref_link = (ref_name = def_page_ref.decorate.name).present? ?
        link_to(ref_name, def_page_ref.url, :target => '_blank') :
        "".html_safe
    if site = def_page_ref.site
      ref_link << ' on '.html_safe unless ref_link.blank?
      ref_link << link_to(site.name, site.home, :target => '_blank')
    end
    ref_link
  end

  def summarize_page_ref pr, options={}
    separator = summary_separator options[:separator]
    header, inward_separator = '', summary_separator(separator)
    if options[:header] || options[:label]
      header = "#{options[:label] || 'Page'} (##{pr.id}): ".html_safe +
          homelink(pr.becomes(PageRef).decorate,
                   nuke_button: !%w{ SitePageRef RecipePageRef }.include?(pr.type))
    end
    referent_summaries = (pr.is_a?(Referrable) ? pr.referents.limit(8) : []).collect { |referent|
      summarize_referent referent, label: "#{referent.class} ##{referent.id}", separator: separator
    }
    summarize_set '', [header] + referent_summaries, separator
  end

end
