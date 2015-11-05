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

end
