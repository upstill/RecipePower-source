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

  def site_feeds_summary site
    napproved = site.approved_feeds.size
    nothers = site.feeds.size - napproved
    q = labelled_quantity(napproved, 'feed').capitalize
    link = (napproved == 1) ?
        feed_path(site.approved_feeds.first) :
        feeds_site_path(site, response_service.admin_view? ? {:item_mode => :table} : {})
    content_tag(:b, link_to_submit(q, link)) +
        " approved (#{labelled_quantity(nothers, 'other').downcase})".html_safe
  end

  def site_recipes_summary site, options={}
    separator = summary_separator options[:separator]
    inward_separator = summary_separator separator
    rcps = site.recipes.loaded? ? site.recipes.first(5) : site.recipes.limit(5).to_a
    safe_join ([labelled_quantity(site.recipes.size, 'cookmark')] +
                  rcps.collect { |rcp| homelink rcp, nuke_button: true }
              ), inward_separator
  end

  def site_pagerefs_summary site, options={}
    separator = summary_separator options[:separator]
    inward_separator = summary_separator separator
    reflines =
    site.page_refs.group(:kind).count.except(PageRef.kinds[:recipe]).collect { |kind_id, count|
      scope = site.page_refs.where kind: kind_id
      prs = scope.limit(5).to_a
      label = labelled_quantity(count, "#{prs.first.kind}")
      safe_join ([label] +
                    prs.collect { |pr|
                      summarize_page_ref pr, label: label, separator: separator
                    }
                ), inward_separator
    }
    safe_join reflines, separator
  end

  def site_finders_summary site
    "#{site.finders.present? ? 'Has' : 'No'} scraping finders".html_safe
  end

  def site_referent_summary site, options={}
    site.referent ? summarize_referent(site.referent, header: true) : 'No Referent (!!?!)'.html_safe
  end

  def site_tags_summary site, options={}
    summarize_set 'Tagged With', site.tags.collect { |tag| homelink tag }, summary_separator
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

  def site_summaries site, admin_view
    set = [site_feeds_summary(site),
           site_recipes_summary(site)]
      set += [
          site_referent_summary(site),
          site_finders_summary(site),
          (summarize_page_ref(site.page_ref, label: "site page ref") if site.page_ref),
          site_pagerefs_summary(site),
          site_tags_summary(site)
      ] if admin_view
    summarize_set '', set
  end
end
