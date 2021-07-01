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

  # Call a block for each .yml file in the configs/sitedata directory
  def for_configs
    yml_root = Rails.root.join 'config', 'sitedata'
    ymls = Dir.entries( yml_root ).find_all { |fname| fname.match /\.yml$/ }
    ymls.each do |filename|
      filename = yml_root + filename
      data = YAML.load_file filename
      pr = PageRef.find_by_url data[:sample_url]
      if site = pr&.site
        yield site, data
      else
        puts "!!! Can't locate site for sample '#{data[:sample_url]}"
      end
    end
  end

  # For sites that don't have one, build a test file from test_template.erb
  task :build_test_templates => :environment do
    # Acquire the template file from the tests directory
    template = nil
    infile = Rails.root.join 'test', 'sites', 'test_template.rb.erb'
    File.open(infile, 'r') { |f| template = f.read }
    erb = ERB.new template

    for_configs do |site, data|
      base = PublicSuffix.parse(URI(site.home).host).domain.gsub( '.', '_dot_')
      outfile = Rails.root.join('test', 'sites', base+'_test'+'.rb')
      next if File.exist? outfile # New files only, please

      @testclass = base.camelcase
      datahash = { }
      datahash[:grammar_mods] = struct_to_str(data[:grammar_mods], 3) if data[:grammar_mods] # JSON.pretty_generate(site.grammar_mods).gsub(/"([^"]*)":/, ":\\1 =>").gsub(/\bnull\b/, 'nil') if site.grammar_mods
      datahash[:trimmers] = data[:trimmers].to_s if data[:trimmers].present?
      datahash[:selector] = '"' + data[:selector].to_s + '"' if data[:selector].present?
      datahash[:sample_url] = "'" + data[:sample_url] + "'" if data[:sample_url].present?
      datahash[:sample_title] = "'" + (data[:sample_title] || "Title here, please") + "'"
      @sitedata = datahash.collect { |key, value|
        "\t\t@#{key} = #{value}"
      }.join "\n"
      File.open(outfile,"w") do |file|
        file.write erb.result(binding)
      end
      puts ">> Created ERB output at: #{outfile} for site #(#{site.id}) '#{site.name}'"
    end
  end

  # Record parsing data from sites in individual files, suitable for checkin
  task :save_parsing_data => :environment do
    selector_map = []
    Finder.
        includes(:site).
        where(label: 'Content').
        pluck( :site_id, :selector ).
        each { |pair| selector_map[pair.first] = pair.last }
    Site.all.each do |site|
      next if site.trimmers.empty? && site.grammar_mods.empty? && (selector = selector_map[site.id]).blank?
      # Get a sample for the site and its title
      if pr = site.sample.present? && PageRef.find_by_url(site.sample)
        sample_title = pr.recipes.first&.title || pr.title
      elsif rcp = site.recipes.first
        site.update_attribute :sample, (site.sample = rcp.url)
        sample_title = rcp.title
      end
      data = {
          root: site.root,
          selector: selector,
          trimmers: site.trimmers,
          grammar_mods: site.grammar_mods,
          sample_url: site.sample,
          sample_title: sample_title
      }.compact
      next if data.blank?
      domain = PublicSuffix.parse(URI(site.home).host).domain
      File.open(Rails.root.join("config", "sitedata", domain + '.yml'), "w") do |file|
        file.write data.to_yaml
      end
    end
  end

  # Get parsing data for sites from YAML files
  task :restore_parsing_data => :environment do
    for_configs do |site, data|
      # Get default values from the file indicated by domain
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
    end
  end
end
