module PageRefsHelper

  def page_ref_homelink pr
    link_to (pr.title.present? ? pr.title : pr.url), pr.url
  end

  def page_ref_showlink pr, ttl=nil
    link_to_submit (ttl || (pr.title.present? ? pr.title : pr.url)), page_ref_path(pr)
  end

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
      header = safe_join([
                             "#{options[:label] || 'Page'} (##{page_ref_showlink(pr, pr.id.to_s)})".html_safe,
                             page_ref_homelink(pr)
                         ], ': '.html_safe,
      )
      inward_separator = summary_separator separator
    end
    referent_summaries = (pr.is_a?(Referrable) ? pr.referents.limit(8) : []).collect { |referent|
      summarize_referent referent, label: "#{referent.class} ##{referent.id}", separator: separator
    }
    summarize_set '', [header] + referent_summaries, separator
  end

end
