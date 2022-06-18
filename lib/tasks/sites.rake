require 'scraping/site_util.rb'
# Recipes for maintaining sites:
# :purge -
# :elide_slash -
# :lookup_url - Confirm that a site can be looked up via its PageRef's url
# :reports -
#
# Three tasks to link the parsing data of sites to:
# 1) a config file (in config/sitedata) that expresses the data, to keep it under source control
# 2) a test file (in test/sites) which tests said data on a sample file from the site
# :build_test_templates - For sites that don't have one, build a test file from test/sites/test_template.erb
# :extract_parsing_data - Pull parsing data from the database into config files, one for each site
# :assert_parsing_data - Restore parsing data from config files into the database
# THIS SHOULD BE DONE AFTER A ROUND OF TESTING, IN PREPARATION FOR MOVING BETWEEN DEVELOPMENT AND PRODUCTION
namespace :sites do
  desc "TODO"

  # We need to be able to assume that the sample page for a site
  # actually has that site for its home. Throw an error if it doesn't.
  def check_sample_against_site sample_url, site

  end

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

  # For sites that don't have one, build a test file from test/sites/test_template.erb     
  # WILL NOT OVERWRITE EXISTING TEST FILES
  task :build_test_templates, [:arg] => :environment do  |t, args|
    # Acquire the template file from the tests directory
    template = nil
    infile = Rails.root.join test_dir, 'test_template.rb.erb'
    File.open(infile, 'r') { |f| template = f.read }
    erb = ERB.new template

    # Confirm that the provided sitename represents an extant site.
    # If not, throw an error
    if (sitename = site_root args[:arg]) && !File.exist?(config_file_for(sitename)) # Site name specified
      if !(Site.where(root: sitename).exists? || Site.where(root: 'www.'+sitename).exists?)
        candidates = Site.where 'root ILIKE ?', "%#{sitename}%"
        # No such site => Report error and suggest candidate roots
        err = "No site matches '#{sitename}'."
        names = candidates.pluck(:root)
        list = names[0..-2].join("', '") + "' or '#{names[-1]}"
        err << "\nPerhaps you meant '#{list}'?" if candidates.present?
        raise err
      end
    end

    # For all extant config files (or just that for the given sitename), construct the test template
    for_configs(sitename) do |site, data|
      testfile = test_file_for site

      # New test files only, please
      if File.exist? testfile
        puts "Test file '#{testfile}' already exists for '#{sitename}'" if sitename
        next
      end

      @testclass = (test_file_for site, base_only: true).camelcase
      datahash = { }
      datahash[:grammar_mods] = struct_to_str(data[:grammar_mods], 3) if data[:grammar_mods] # JSON.pretty_generate(site.grammar_mods).gsub(/"([^"]*)":/, ":\\1 =>").gsub(/\bnull\b/, 'nil') if site.grammar_mods
      datahash[:trimmers] = data[:trimmers].to_s if data[:trimmers].present?
      datahash[:selector] = '"' + data[:selector].to_s + '"' if data[:selector].present?
      datahash[:sample_url] = "'" + data[:sample_url] + "'" if data[:sample_url].present?
      datahash[:sample_title] = "'" + (data[:sample_title] || "Title here, please") + "'"

      check_sample_against_site datahash[:sample_url], site

      @sitedata = datahash.collect { |key, value|
        "\t\t@#{key} = #{value}"
      }.join "\n"
      File.open(testfile,"w") do |file|
        file.write erb.result(binding)
      end
      puts ">> Created ERB output at: #{testfile} for site #(#{site.id}) '#{site.name}'"
    end
  end

  # Record parsing data from sites in config files, suitable for checkin
  # site => config/sitedata/<site.url>.yml for all sites that have Content (or one, as specified by :arg)
  task :backup_parsing_data, [:arg] => :environment do  |t, args|
    # Derive an array of sites to process. If one is given in :arg, use that. Otherwise, go through all sites
    siteroot = args[:arg]
    sites = []
    if siteroot
      site = Site.find_by(root: siteroot) || Site.find_by(root: 'www.'+siteroot)
      raise "ERROR: there is no site with root #{siteroot}" if !site
      puts "Backup parsing data from database for Site##{site.id}, root '#{site.root}': '#{site.sample}'"
      sites << site
    end
    sites = Site.all if sites.empty?
    
    # Prefetch all the Content selectors for all sites into a hash indexed by site id
    selector_map = Hash[Finder.includes(:site).where(label: 'Content').pluck( :site_id, :selector )]
    sites.each do |site|
      selector = selector_map[site.id]
      next if site.trimmers.empty? && site.grammar_mods.empty? && selector.blank?
      data = {
          root: site.root.sub(/^www./,''),
          selector: selector,
          trimmers: site.trimmers,
          sample_url: site.sample,
          sample_title: '',
          grammar_mods: site.grammar_mods
      }.compact
      next if data.blank?
      puts "...backing up Site##{site.id} of root '#{site.root}' as '#{data[:root]}'"
      # Get the sample for the site and its title from the config file, if any
      for_configs(site) do |site, config_data|
        data[:sample_url] = config_data[:sample_url]
        data[:sample_title] = config_data[:sample_title]
      end
      File.open(config_file_for(site), "w") do |file|
        file.write data.except(:sample_url, :sample_title).to_yaml
        file.write data.slice(:sample_url, :sample_title).to_yaml.sub("---\n",'')
      end
    end
  end

  # Get parsing data for sites from YAML files
  # THIS SHOULD BE DONE AFTER A ROUND OF TESTING, IN PREPARATION FOR MOVING BETWEEN DEVELOPMENT AND PRODUCTION
  # config/sitedata/<url>.yml => Site.fetch(root: data[:root]) for *.yml
  task :restore_parsing_data, [:arg] => :environment do |t, args|
    sitename = args[:arg]
    for_configs(sitename) do |site, data|
      puts "Restore parsing data to database for Site##{site.id}, root '#{site.root}': '#{site.sample}'"
      # Get default values from the file indicated by domain
      # Move the selector into a finder attached to the site
      if data[:selector]
        if finder = site.finders.find_by(label: 'Content')
          if finder.selector != data[:selector]
            finder.selector = data[:selector]
            finder.save
          end
        else
          if site.persisted?
            site.finders.create label: 'Content', selector: data[:selector], attribute_name: 'html'
          else
            site.finders.build label: 'Content', selector: data[:selector], attribute_name: 'html'
          end
        end
      end
      site.sample = data[:sample_url] if data[:sample_url]
      site.grammar_mods = data[:grammar_mods]
      site.trimmers = data[:trimmers]
      site.save if site.changed?
    end
  end

  def collect_tags tagtype
    puts "#{tagtype} tag(s)? (one per line until blank line)"
    newtags = []
    line = ''
    # while line.present?
    while (line = STDIN.gets.chomp.encode('UTF-8')).present?
      unless Tag.strmatch(line, tagtype: tagtype).exists?
        newtags << Tag.assert(line, tagtype)
      end
      line = ''
      x=2
    end
    # Now newtags is a set of new tags matching the strings
    newtags
  end

  def report_problems redoes
    if (failures = redoes.keep_if { |recipe| recipe.content.nil? }).present?
      ids = failures.map(&:id).map(&:to_s)
      if ids.count == 1
        puts "FYI: Recipe ##{ids.first} (#{failures.first.title}) has no content."
      else
        ids = (ids[0..-2].join ', ') + " and #{ids.last}"
        puts "FYI: #{failures.count} recipes (ids #{ids}) have no content."
      end
    end
  end

  # Enforce parsing on the recipes in a site
  task :probe_parsings, [:site_id] => :environment do |t, args|
    site = Site.find(args[:site_id].if_present || 3965)
    ss = SiteServices.new site
    # Examine each recipe for consistency of content
    redoes = ss.probe_parsings
    if redoes.empty?
      puts "All recipes are copacetic!!"
    else
      # Try once more to parse the recipes that need redoing
      start_count = redoes.count
      redoes.each { |r|
        r.refresh_attributes [:content]
        r.ensure_attributes [:content]
        if r.errors.any?
          puts "!!! Parsing error: #{r.errors.full_messages}"
        else
          r.save
        end
      }
      # Having reparsed all recipes, see which are still not complete
      remainder = ss.probe_parsings(redoes)
      end_count = remainder.count
      # Before proceeding, report on recipes that can't be fetched
      remainder.keep_if do |recipe|
        next true if recipe.parser_input.present?
        if recipe.parser_input.blank?
          # Check that the page_ref has content, updating it if not
          page_ref = recipe.page_ref
          if page_ref.content.blank?
            page_ref.request_attributes [:content]
            page_ref.ensure_attributes [:content]
            if page_ref.content.blank?
              gleaning = page_ref.gleaning
              gleaning.request_attributes [:content]
              gleaning.ensure_attributes [:content]
              page_ref.request_attributes [:content]
              page_ref.ensure_attributes [:content]
            end
          end
          next true if recipe.parser_input.present?  # Got it
        end
        # It's a waste of time trying to parse a recipe that has no content to parse.
        puts "Recipe ##{recipe.id} (#{recipe.title}) has no content to parse."
        puts "\tURI #{recipe.url}"
        puts "\tGleaning HTTP status #{recipe.page_ref.gleaning.http_status}" if recipe&.page_ref&.gleaning
        false
      end
      report = "Fixed #{start_count - end_count} out of #{start_count} recipes."
      ninaccessible = end_count - remainder.count
      report << "\nDispensed with #{ninaccessible} that #{ninaccessible > 1 ? 'have' : 'has'} no parseable content (perhaps due to dead page?)" if ninaccessible > 0
      puts report
      puts "#{remainder.count} recipes fail parsing. Shall we address the issues?"
      line = 'Y'
      line = STDIN.gets.chomp
      unless line.match /[yY]/
        puts "Okay then. Bye!"
        report_problems redoes
      else
        # So now we have a batch of problematic recipes. We'll attempt to redress problems by adding ingredient,
        # condition and/or unit tags.
        ParserServices.report_on = true
        remainder.each do |recipe|
          next unless recipe.content.present? # We bail if parsing failed entirely
          # First, parse the recipe again for a fresh presentation
          recipe.refresh_attributes [:content]
          recipe.ensure_attributes [:content]
          ss.parsing_report recipe, recipe.url
          %w{ Ingredient Condition Unit }.each { |tagtype|
            next unless (newtags = collect_tags(tagtype)).present? # Interactively get some tags to fix the parse
            # If any new tags are provided, reparse the recipe using them
            tagsumm = newtags.map(&:name).join "', '"
            puts "New #{tagtype} tag(s) specified: '#{tagsumm}'"
            unless newtags.all? { |tag| Lexaur.augment_cache tagtype, tag.name, tag.id }
              # Roll back the tags database
              x = 2 # Stop here please!
            end
            # Now reparse the recipe to see how we fare...
            recipe.refresh_attributes [:content]
            recipe.ensure_attributes [:content]
            # ...and report the result
            break unless ss.parsing_report recipe, "after adding #{tagtype} tags"
          }
        end
      end
    end
  end

  task :my_task, [:arg1, :arg2] do |t, args|
    puts "Args were: #{args} of class #{args.class}"
    puts "arg1 was: '#{args[:arg1]}' of class #{args[:arg1].class}"
    puts "arg2 was: '#{args[:arg2]}' of class #{args[:arg2].class}"
  end

end
