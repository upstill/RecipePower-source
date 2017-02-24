namespace :sites do
  desc "TODO"
  task :purge => :environment do
    s = Site.first
    p = PageRef.first
    domains = SitePageRef.pluck(:domain).uniq
    domains.each { |domain|
      sprs = SitePageRef.includes(:sites).where(domain: domain)
      nsites = 0
      roots = sprs.collect { |spr|
        pairs = spr.sites.pluck :id, :root
        nsites += pairs.count
        "    PageRef ##{spr.id}: "+pairs.collect { |pair| "#{pair.last} (#{pair.first})"}.join(', ')
      }
      if nsites > 1 # Indicating a potentially redundant domain
        puts "#{domain}:"
        puts roots
        puts
      end
    }
  end

end
