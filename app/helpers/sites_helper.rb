module SitesHelper

  def crack_sample site
    
    extractions = SiteServices.new(site).extract_from_page site.sample, :label => [:Title, :URI]
    if extractions[:Title] && extractions[:URI]
      link_to extractions[:Title], extractions[:URI]
    else
      "[site sample can't be read]"
    end

  end
  
  def trimmed_sample
    ss = SiteServices.new(@site)
    extractions = ss.extract_from_page @site.sample, :label => :Title
    ss.trim_title extractions[:Title] || ""
  end
  
  def show_sample(site)
    link_to "Sample", site.sample
  end

  def site_similars site
    SiteReference.where(host: site.reference.host).map(&:site).uniq.collect { |other|
      button_to_submit "Absorb #{other.home}", absorb_site_path(site, other_id: other.id), :method => :post, :button_size => "sm" unless other.id == site.id
    }.compact.join.html_safe
  end

  def site_homelink decorator, options={}
    decorator = decorator.decorate unless decorator.is_a?(Draper::Decorator)
    (data = (options[:data] || {}))[:report] = polymorphic_path [:touch, decorator.object]
    link_to_submit( decorator.title,
                    decorator.object,
                    options.merge(data: data)) + '&nbsp;'.html_safe +
        link_to( "",
                 decorator.url,
                 class: 'glyphicon glyphicon-play-circle',
                 style: 'color: #aaa',
                 :target => '_blank')

  end

  def site_feeds_summary site
    ft = nil
    napproved = site.feeds.where(approved: true).count
    nothers = site.feeds.count - napproved
    q = labelled_quantity( napproved, 'feed').capitalize
    summ = content_tag :b, link_to_submit( q, site_path(site, result_type: 'sites.feeds', item_mode: 'table'))
    # response_service.admin_view? ? (summ + " approved; #{site.feeds.count - napproved} others".html_safe) : summ
    summ += " approved; #{labelled_quantity nothers, 'other'}".html_safe
  end

end
