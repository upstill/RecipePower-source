module SitesHelper
    def crack_sample
        ttlurl = @site.yield :Title
        title = ttlurl[:Title]
        unless url = ttlurl[:URI]
            url = (@site.yield :URI)[:URI] || ""
        end
        link_to title, url
    end
    def show_sample(site)
        url = site.sampleURL
        link_to url, url
    end
end
