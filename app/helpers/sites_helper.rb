module SitesHelper
    def show_sample(site)
        url = site.site+(site.sample||"")
        debugger unless findings = site.crack_page(url, :Recipe)
        title = findings && findings.result(:Title) 
        title = title ? site.fix_title(title) : url
        link_to title, url
    end
end
