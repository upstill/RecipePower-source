module SitesHelper

  def crack_sample
    
    extractions = SiteServices.new(@site).extract_from_page @site.sample, :label => [:Title, :URI]
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

end
