module SitesHelper
  def crack_sample
    ttlurl = @site.yield :Title
    title = ttlurl[:Title]
    unless url = ttlurl[:URI]
        url = (@site.yield :URI)[:URI] || ""
    end
    link_to title, url
  end
  
  def trimmed_sample
    @site.trim_title (@site.yield :Title)[:Title] || ""
  end
  
  def show_sample(site)
    url = site.sampleURL
    link_to "Sample", url
  end
  
  def site_fit_pic(site, placeholder_image="MissingPicture.png", selector=nil)
    page_fitPic site.logo, site.id, placeholder_image, selector
  end

end
