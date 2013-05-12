module SitesHelper
  def crack_sample
    
    extractions = SiteServices.new(@site).extract_from_page @site.sampleURL, :label => [:Title, :URI]
    link_to extractions[:Title], extractions[:URI]
  end
  
  def trimmed_sample
    ss = SiteServices.new(@site)
    extractions = ss.extract_from_page @site.sampleURL, :label => :Title
    ss.trim_title extractions[:Title] || ""
  end
  
  def show_sample(site)
    link_to "Sample", site.sampleURL
  end
  
end
