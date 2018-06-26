module SitesHelper

  def show_sample(site)
    link_to 'Sample', site.sample
  end

  def site_similars site
    safe_join SiteServices.new(site).similars.collect { |other|
      [
          button_to_submit( "Merge into ##{other.id} '#{other.home}'", absorb_site_path(other, other_id: site.id), :method => :post, :button_size => "sm"),
          button_to_submit( "Absorb ##{other.id} '#{other.home}'", absorb_site_path(site, other_id: other.id), :method => :post, :button_size => "sm")
      ] if site.id != other.id
    }.compact.flatten
  end


  def site_nuke_button site, options={}
    options = {
        button_style: 'danger',
        button_size: 'xs',
        method: 'DELETE'
    }.merge options
    SiteServices.new(site).nuke_message link_to_submit('DESTROY', site, options)
  end

  def site_glean_button site, options={}
    options = {
        button_size: 'xs' #, method: 'POST'
    }.merge options
    link_to_submit('GLEAN', glean_site_path(site, :what => :table, :force => true), options)
  end

  def site_pagerefs_summary site, options={}
  end

  def site_feeds_summary site
  end

  def site_summaries site, admin_view
    napproved = site.approved_feeds.size
    nothers = site.feeds.size - napproved
    q = labelled_quantity(napproved, 'feed').capitalize
    link = (napproved == 1) ?
        feed_path(site.approved_feeds.first) :
        feeds_site_path(site, response_service.admin_view? ? {:item_mode => :table} : {})
    feed_summary = content_tag(:b, link_to_submit(q, link)) +
        " approved (#{labelled_quantity(nothers, 'other').downcase})".html_safe

    page_refs_summary =
        site.page_refs.group(:kind).count.except(PageRef.kinds[:recipe]).collect { |kind_id, count|
          # site_page_refs_kind_summary site.page_refs.where(kind: kind_id)
          scope = site.page_refs.where kind: kind_id
          report_items(scope, "#{scope.first.kind} page", limit: 5) { |pr| page_ref_identifier pr }
        }.if_present

    set = [feed_summary]
    set << report_items(site.recipes, 'cookmark', limit: 5) { |rcp| homelink rcp, nuke_button: true }
    if admin_view
      set << (site.referent ? referent_summary(site.referent, header: true) : 'No Referent (!!?!)'.html_safe)
      set << "#{site.finders.present? ? 'Has' : 'No'} scraping finders".html_safe
      set << page_ref_identifier(site.page_ref, 'site home page')
      set << page_refs_summary
      set << report_items(site.tags, 'Tagged With', fixed_label: true)

    end
    format_table_tree set.flatten(1)

  end
end
