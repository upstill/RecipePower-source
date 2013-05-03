class FeedServices
  
# Scour all sites for feeds. Summarize the found sets.
  def self.scrape_all(n = -1)
    count = skunked = added = feedcount = 0
    rejects = []
    Site.all.each { |site|
      count = count+1
      next if site.feeds.count > 0
      added = added - site.feeds.count
      rejects = rejects + self.scrape_page(site)
      added = added + site.feeds.count
      if site.feeds.count == 0
        skunked = skunked+1 
      else
        feedcount = feedcount + site.feeds.count
      end
      n=n-1
      break if n==0
    }
    puts count.to_s+" sites examined"
    puts (count-skunked).to_s+" sites with at least one feed"
    puts feedcount.to_s+" nominal feeds captured"
    puts added.to_s+" feeds added this go-round"
    puts "Rejected #{rejects.count.to_s} potential feeds:"
    puts "\t"+rejects.join("\n\t")
  end
  
  # Examine the sample page of a site (or a given other page) for RSS feeds
  def self.scrape_page(site, page_url=nil)
    rejects = []
    ((page_url && [page_url]) || [site.sampleURL, site.home]).each do |page_url|
      begin 
        return [] unless (ou = open page_url) && (doc = Nokogiri::HTML(ou))
      rescue Exception => e
        return []
      end
      puts "URL: "+page_url
      candidates = {}
      # We find the following elements:
      # <a> elements where the link text OR the title attribute OR the href attribute includes 'RSS', 'rss', 'feedburner' or 'feedblitz'
      # <link> tags with type="application/rss+xml": title and href attributes
      doc.css("a").each { |link| 
        content = link.inner_html.encode("UTF-8")
        href = link.attributes["href"].to_s
        next if href == "#"
        if content.include?("RSS") || content.include?("rss") || href.match(/rss|feedburner|feedblitz|atom/i)           
          candidates[href] = content
        end
      }
      doc.css("link").each { |link|
        href = link.attributes["href"].to_s
        next if href == "#"
        if link.attributes["type"].to_s =~ /^application\/rss/i
          candidates[href] = link.attributes["title"].to_s
        end
      }
      candidates.keys.each do |href| 
        content = candidates[href].truncate(250)
        begin
          # For some strange reason we've seen feed URLs starting with 'feed:http:'
          url = URI.join( page_url, href).to_s.sub(/feed:http:/, "http:")
        rescue Exception => e
          url = nil
        end 
        unless url.blank? || Feed.exists?(url: url) || !(feed = Feed.new( url: url, description: content))
          if feed.save
            site.feeds << feed 
          else
            rejects << "#{feed.url} (from #{page_url})"
          end
        end
      end
    end
    rejects
  end
  
end