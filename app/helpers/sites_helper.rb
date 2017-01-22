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
    scope = site.recipes_scope
    p = labelled_quantity(scope.count, 'cookmark')
    p += ': ' + homelink(scope.first) if scope.count == 1
    content_tag :p, p.html_safe
  end

end
