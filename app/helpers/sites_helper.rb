module SitesHelper

  def show_sample(site)
    link_to 'Sample', site.sample
  end

  def site_similars site
    SiteServices.new(site).similars.collect { |other|
      button_to_submit "Absorb #{other.home}", absorb_site_path(site, other_id: other.id), :method => :post, :button_size => "sm" unless other.id == site.id
    }.compact.join.html_safe
  end

  def site_feeds_summary site
    napproved = site.approved_feeds.count
    nothers = site.feeds.count - napproved
    q = labelled_quantity( napproved, 'feed').capitalize
    link = (napproved == 1) ?
        feed_path(site.approved_feeds.first) :
        feeds_site_path(site, response_service.admin_view? ? { :item_mode => :table } : {} )
    summ = content_tag :b, link_to_submit( q, link)
    summ += " approved (#{labelled_quantity( nothers, 'other').downcase})".html_safe
  end

  def site_recipes_summary site
    scope = site.recipes
    p = labelled_quantity(scope.count, 'cookmark')
    p = safe_join [p, homelink(scope.first)], ': '.html_safe if scope.count == 1
    tag(:br) + p
  end

  def site_pagerefs_summary site
    summ =
    safe_join (PageRef.types - ['recipe']).collect { |prtype|
      scope = site.method("#{prtype.to_s}_page_refs").call
      labelled_quantity(scope.count, prtype) if scope.exists?
    }.compact, tag(:br)
    (tag(:br) + summ) if summ.present?
  end

  def site_finders_summary site
    tag(:br) + "#{site.finders.present? ? 'Has' : 'Does not have'} scraping finders".html_safe
  end

  def site_referent_summary site
    tag(:br) +
        if site.referent
          safe_join [summarize_referent(site.referent), summarize_ref_expressions(site.referent)], tag(:br)
        else
          '...site has no referent (!!?!)'.html_safe
        end
  end

  def site_tags_summary site
    ts = summarize_set 'Tagged With', site.tags.collect { |tag| tag_homelink tag }
    (tag(:br) + ts) if ts.present?
  end
end
