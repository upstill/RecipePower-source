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

  task :elide_slash => :environment do
    PageRef.where(type: 'SitePageRef').each { |spr|
      begin
        uri = URI spr.url
        uri.path = '' if uri.path == '/'
        url = uri.to_s
      rescue
        puts "Bad URL on ##{spr.id}: '#{spr.url}'"
        next
      end
      unless spr.url == url
        puts "Fixing ##{spr.id}: '#{spr.url}'"
        spr.aliases -= [url]
        spr.aliases |= [spr.url]
        spr.url = url
      end
    }
  end

  # Confirm that a site can be looked up via its PageRef's url
  task :lookup_url => :environment do
    PageRef.where(type: 'SitePageRef').each { |spr|
      found = SitePageRef.find_by_url(spr.url)
      if !found
        "#{spr.url} (#{spr.id}) not findable"
      elsif found.id != spr.id
        "'#{spr.url}' (#{spr.id}) finds '#{spr.url}' (#{spr.id})"
      end
    }
  end

  task :reports => :environment do
    # Every site needs to have a name (referent) and home (page_ref)
    puts Site.includes(:referent).to_a.collect { |site|
      next if site.referent
      "Site ##{site.id} ('#{site.home}' has no referent (ERROR) #{('but title is '+site.page_ref.title.to_s) if site.page_ref}" +
          "\n\t...with #{site.page_refs.about.count} DefinitionPageRef(s) and #{site.page_refs.recipe.count} RecipePageRef(s)"
    }.compact.sort
    puts Site.includes(:page_ref).to_a.collect { |site| "Site ##{site.id} ('#{site.home}' has no page_ref (ERROR)" unless site.page_ref }.compact.sort

    # Every PageRef should have at least tried to go out
    badrefids = SitePageRef.bad.where.not(http_status: 200).pluck(:id)
    puts [
        (SitePageRef.where(url: nil).count.to_s + ' nil site urls'),
        ((SitePageRef.virgin.count+SitePageRef.processing.count).to_s + ' Site Page Refs need processing'),
        (SitePageRef.where(http_status: nil).count.to_s + ' Site Page Refs have no HTTP status'),
        (badrefids.count.to_s + " bad SitePageRefs: \n\t" + SitePageRef.where(id: badrefids).collect { |spr|
          "#{spr.id}: '#{spr.url}' (for site ##{spr.site_id}) -> #{spr.http_status}"
        }.join("\n\t"))
    ]
  end

  # For sites that don't have one, build a test file from test_template.erb
  task :build_test_templates => :environment do
    # Acquire the template file from the tests directory
    template = nil
    infile = Rails.root.join 'test', 'sites', 'test_template.rb.erb'
    File.open(infile, 'r') { |f| template = f.read }
    erb = ERB.new template

    ymls = Dir.entries( Rails.root.join 'config', 'sitedata').find_all { |fname| fname.match /\.yml$/ }

    Site.where(id: 3667).each do |site| # includes(:page_ref).all.each do |site|
      selector = site.finders.find_by(label: 'Content')&.selector
      next if site.trimmers.blank? && site.grammar_mods.empty? && selector.blank?
      base = PublicSuffix.parse(URI(site.home).host).domain.gsub( '.', '_dot_')
      outfile = Rails.root.join('test', 'sites', base+'_test'+'.rb')
      next if File.exist? outfile

      @testclass = base.camelcase
      datahash = { }
      datahash[:grammar_mods] = struct_to_str(site.grammar_mods, 3) # JSON.pretty_generate(site.grammar_mods).gsub(/"([^"]*)":/, ":\\1 =>").gsub(/\bnull\b/, 'nil') if site.grammar_mods
      datahash[:trimmers] = site.trimmers.to_s if site.trimmers.present?
      datahash[:selector] = '"' + selector.to_s + '"' if selector.present?
      @sitedata = datahash.collect { |key, value|
        "@#{key} = #{value}"
      }.join "\n"
      @page = site.sample # datahash[:sample_url]
      @title = datahash[:sample_title] || "Title here, please"
      result = erb.result binding
      File.open(outfile,"w") do |file|
        file.write result
      end
      puts ">> Created ERB output at: #{outfile} for site #(#{site.id}) '#{site.name}'"
    end
  end

  # Record parsing data from sites in individual files, suitable for checkin
  task :save_parsing_data => :environment do
    Site.where(id: [3667]).includes(:page_ref).each { |site|
    # Finder.includes(:site => :page_ref).where(label: "Content").each { |finder|
    # site = finder.site
      finder = site.finders.find_by(label: 'Content')
      domain = PublicSuffix.parse(URI(site.home).host).domain
      if pr = PageRef.find_by_url(site.sample)
        sample_title = pr.recipes.first&.title || pr.title
      end
      data = {
          sample_url: site.sample,
          sample_title: sample_title,
          root: site.root,
          selector: finder.selector,
          trimmers: site.trimmers,
          grammar_mods: site.grammar_mods
      }.compact
      next if data.blank?
      filename = Rails.root.join("config", "sitedata", domain+'.yml')
      File.open(filename,"w") do |file|
        file.write data.to_yaml
      end
    }
  end

  # Get parsing data for sites from YAML files
  task :restore_parsing_data => :environment do
    Site.where(id: [3667]).includes(:page_ref).each { |site|
    #Finder.includes(:site => :page_ref).where(label: "Content").each { |finder|
    #  site = finder.site
      domain = PublicSuffix.parse(URI(site.home).host).domain
      # Get default values from the file indicated by domain
      filename = Rails.root.join "config", "sitedata", domain + '.yml'
      data = YAML.load_file(filename) if File.exists? filename
      # Move the selector into a finder attached to the site
      if data[:selector]
        if finder = site.finders.find_by(label: 'Content')
          if finder.selector != data[:selector]
            finder.selector = data[:selector]
            finder.save
          end
        else
          site.finders.create(label: 'Content', selector: data[:selector], attribute_name: 'html')
        end
      end
      site.sample = data[:sample_url] if data[:sample_url]
      site.grammar_mods = data[:grammar_mods]
      site.trimmers = data[:trimmers]
      site.save if site.changed?
    }
  end
end
