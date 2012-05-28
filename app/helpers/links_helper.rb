module LinksHelper
    
    # Show a link, using as text the name of the related site
    def present_link link
        (site = Site.by_link link.uri) ? "<a href=\""+link.uri+"\">"+site.name+"</a>" : ""
    end
end
