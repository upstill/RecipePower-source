class SiteServices
  attr_accessor :site

  # Evaluate the site's suitability for deletion
  def nuke_message button
    if site.recipes.exists? || site.feeds.exists?
      # No go: can't delete if there are feeds or recipes associated
      'NO DELETION: site contains recipes and/or feeds'
    elsif site.definition_page_refs.exists?
      button + "CAUTION: site has #{labelled_quantity site.definition_page_refs.count, 'definition page ref'} pointing to it, which will also be destroyed".html_safe
    else
      button
    end
  end

  def self.convert_references
    reports = [ '***** SiteServices.convert_references ********']
    (s = Site.find_by(id: 3463)) && s.destroy
    Site.includes(:references).where(page_ref_id: nil).each { |site| SiteServices.new(site).convert_references if site.references.present? } # Only convert the unconverted
    # Clean up the PageRefs with nil URLs
    PageRef::SitePageRef.where(url: nil).collect { |spr|
      site = Site.find_by(page_ref_id: spr.id)
      spr.destroy
      if site
        site.page_ref = nil
        site.save
        reports << SiteServices.new(site).convert_references
      end
    }
    SiteServices.fix_sites
    SiteServices.fix_roots
    SiteServices.fix_page_refs
    PageRef::SitePageRef.all.each { |pr| PageRefServices.new(pr).ensure_status }
    reports
  end

  def convert_references
    report = "Converting references for site #{site.id}:"
    SiteReference.where(affiliate_id: site.id).each { |reference|
      report += "\n\tMaking SitePageRef for reference ##{reference.id} (#{reference.url})"
      puts "Enqueuing making of SitePageRef for Site ##{site.id} on Reference ##{reference.id} (#{reference.url})"
      reference.bkg_enqueue true, priority: 10
      reference.bkg_wait
      puts "...done"
      # site.page_ref = PageRefServices.convert_reference reference, site.page_ref
    }
    site.reload
    report
  end

  # Ensure that each PageRef (except SitePageRefs) has a corresponding site
  def self.fix_sites
    # Define new sites as needed
    [
        { name: 'NYTimes Diners Journal', root: 'dinersjournal.blogs.nytimes.com', sample: 'http://www.nytimes.com/pages/dining/index.html'},
        { name: 'PBS Food', root: 'www.pbs.org/food', home: 'http://www.pbs.org/food'},
        { name: 'UK TV Good Food', root: 'goodfood.uktv.co.uk', home: 'http://goodfood.uktv.co.uk/'},
        { root: 'goodfood.uktv.co.uk', home: 'http://goodfood.uktv.co.uk' },
        { root: 'ricette.giallozafferano.it', home: 'http://ricette.giallozafferano.it' },
        { root: 'www.dailymail.co.uk', home: 'http://www.dailymail.co.uk' },
        { root: 'www.eatingwell.com', home: 'http://www.eatingwell.com' },
        { root: 'www.theguardian.com', home: 'https://www.theguardian.com' },
        { root: 'ww2.kqed.org/bayareabites', home: 'https://ww2.kqed.org/bayareabites' },
        { root: 'www.yummly.co', home: 'http://www.yummly.com/' },
        { root: 'www.shutterbean.com', home: 'http://www.shutterbean.com' },
        { root: 'www.annies-eats.com', home: 'http://www.annies-eats.com' },
        { root: 'www.bite.co.nz', home: 'http://www.bite.co.nz' },
        { root: 'www.brm-icecream.com', home: 'http://www.brm-icecream.com' },
        { root: 'www.cdkitchen.com', home: 'http://www.cdkitchen.com' },
        { root: 'www.gourmetsleuth.com', home: 'http://www.gourmetsleuth.com' },
        { root: 'www.hogarmania.com', home: 'http://www.hogarmania.com' },
        { root: 'www.lespetitsmacarons.com', home: 'http://www.lespetitsmacarons.com' },
        { root: 'www.tastebook.com', home: 'http://www.tastebook.com' },
        { root: 'www.thepauperedchef.com', home: 'http://www.thepauperedchef.com' },
        { root: 'www.washingtonpost.com', home: 'http://www.washingtonpost.com' },
        { root: 'bestbyfarr.wordpress.com', home: 'https://bestbyfarr.wordpress.com' },
        { root: 'en.wikipedia.org', home: 'https://en.wikipedia.org' },
        { root: 'patijinich.com', home: 'https://patijinich.com' },
        { root: 'www.evernote.com', home: 'https://www.evernote.com' },
        { root: 'saltandwind.com', home: 'http://saltandwind.com' },
        { root: 'www.washingtonpost.com/lifestyle/food', home: 'https://www.washingtonpost.com/lifestyle/food' },
        { name: 'playing with fire and water', root: 'www.playingwithfireandwater.com', home: 'http://www.playingwithfireandwater.com' },
        { name: 'Mexico Cooks', root: 'mexicocooks.typepad.com/mexico_cooks', home: 'http://mexicocooks.typepad.com/mexico_cooks/'},
        { name: 'The Guardian UK Food&Drink', root: 'www.theguardian.com/lifeandstyle', sample: 'https://www.theguardian.com/lifeandstyle/food-and-drink'}
    ].each { |initializer|
      unless Site.where(root: initializer[:root]).exists?
        s = Site.create(initializer)
        if s.page_ref && s.page_ref.title.present?
          s.name = s.page_ref.title
          s.save
        end
      end
    }
    [ PageRef::RecipePageRef, PageRef::DefinitionPageRef ].each { |refclass|
      refclass.where(site_id: nil).collect { |pageref|
        puts "Fixing site for #{pageref.type} ##{pageref.id}: #{pageref.url}"
        if pageref.site = Site.find_for(pageref.url)
          pageref.save
          pageref
        end
      }.compact
    }
  end

  def self.fix_page_refs
    # Ensure that every site with a viable home link has a page_ref
    Site.where(page_ref_id: nil).collect { |site| SiteServices.new(site).fix_page_ref }
  end

  def fix_page_ref
    # Ensure that every site with a viable home link has a page_ref
    puts "Fixing PageRef for Site ##{site.id} ('#{site.home}')"
    if site.home.present?
      site.page_ref = PageRef::SitePageRef.fetch site.home
      site.save
      if site.errors.any?
        puts "...fails to get PageRef: #{site.errors.messages}"
      else
        puts "...gets PageRef ##{site.page_ref_id}"
      end
      puts fix_root if site.root.blank?
    else
      puts "...couldn't create PageRef for empty home (!!)"
    end
  end

=begin
  def self.fix_referents
    Site.includes(:page_ref).where(referent_id: nil).collect { |site|
      if (title = site.page_ref && site.page_ref.title)
        site.name =
      end
      }
  end
=end

  def self.fix_roots
    # Site.find_by(sample: '/').destroy
    if site = Site.find_by(id: 3332)
      site.home.sub! '[node-path]', ''
      site.save
    end

    Site.includes(:page_ref).where(root: nil).collect { |site|
      ss = SiteServices.new(site)
      ss.fix_root if site.page_ref
    }.compact # Only convert the unconverted
  end

  def fix_root
    new_root =
        (subpaths(site.home).last if site.home.present? && subpaths(site.home)) ||
            (subpaths(site.sample).first if site.sample.present? && subpaths(site.sample))
    return if new_root.blank? || (new_root == site.root)
    begin
      report = ["Site ##{site.id} '#{site.name}' w. home '#{site.home}', sample '#{site.sample}', root '#{site.root}'",
                "    to get root '#{new_root}':"]
      if other = Site.find_by(root: new_root)
        # There's already a site with this root => merge with that one
        report << "    Site ##{other.id} '#{other.name}' w. home '#{other.home}', sample '#{other.sample}' already has root '#{other.root}'"
        other.absorb site
        report << "    #{other.errors.messages}"
      else
        # Should be good to go
        site.root = new_root
        site.save
        report << "    Success!"
      end
    rescue Exception => e
      report << e.to_s
    end
    return report
  end

=begin
  def self.test_lookup n=-1
    Site.all[0..n].map(&:id).each { |id| self.test_lookup_by_id id }
    nil
  end

  def self.test_lookup_by_id id
    s1 = Site.find id
    s1.recipes.each { |rcp|
      s2 = rcp.site # SiteReference.lookup_site rcp.url
      if s2 != s1
        puts "Recipe ##{rcp.id} #{rcp.url}..."
        puts "...from site ##{s1.id} (#{s1.reference.url}) finds another site:"
        puts "\t... site ##{s2.id} (#{s2.reference.url})"
        canon = SiteReference.canonical_url(rcp.url)
        puts "\t... due to Reference(s) off of canonical link #{canon}:"
        SiteReference.lookup(canon).each { |sr| puts "\t\t##{sr.id} with url #{sr.url}" }
      end
    }
  end
=end

  def initialize site=nil
    @site = site
  end

  public

  # Make sure the given uri isn't relative, and make it absolute if it is
  def resolve(candidate)
    return candidate if candidate.blank? || (candidate =~ /^\w*:/)
    begin
      URI.join(@site.home, candidate).to_s
    rescue
      candidate
    end
  end

  # Doctor a scanned title coming in from a web page, according to the site parameters
  def trim_title(ttl)
    if ttl
      unless @site.ttlcut.blank?
        re = /#{@site.ttlcut}/
        if md = re.match(ttl)
          ttl = md[1] || ttl.sub(re, '')
        end
      end
      ttl.gsub(/\s+/, ' ').strip
    end
  end

  def get_input(prompt='? ')
    print prompt
    gets.strip
  end

=begin
  # Return the set of finders that apply to the site (those assigned to the site, then global ones)
  def all_finders
    # Give the DefaultFinders and CandidateFinders a unique, site-less finder from the database
    @site.finders +
        (@@DefaultFinders + @@CandidateFinders).collect { |finderspec|
          finderspec[:finder] ||= Finder.where(finderspec.slice(:label, :selector, :attribute_name).merge site_id: nil).first_or_create
    }
  end
=end

  def scrape
    # extractions = extract_from_page(@site.home)
    puts "Site # #{@site.id}"
    puts "\tname: #{@site.name}"
    puts "\thome: (#{@site.home})"
    puts "\tdescription: (#{@site.description})"
    puts "\tlogo: (#{@site.logo})"
    if results = FinderServices.glean(@site.home, @site)
      results.labels.each { |label| puts "\t\t#{label}: #{results.result_for(label)}" }
    else
      puts "!!! Couldn't open the page for analysis !!!"
    end
    results
  end

  def self.scrape_for_feeds(n=-1)
    Site.all[0..n].each { |site| Delayed::Job.enqueue site, priority:5 }
  end

  # Examine each site and confirm that its sample page URL matches a recipe
  def self.QA
    # Build a table mapping recipes into sites
    site_map = []
    Recipe.all.each do |recipe|
      if site = recipe.site
        if site_map[site.id]
          site_map[site.id] << recipe
        else
          site_map[site.id] = [recipe]
        end
      else
        puts "!!!Recipe #{recipe.title} has no site!"
      end
    end
    sought = found = matched = 0
    suspect = []
    bogus_in = []
    moved_in = []
    bogus_out = []
    moved_out = []
    unmapped = []
    Site.all.each do |site|
      puts '---------------'
      sought = sought+1

      # Probe the site's sample URL for validity or relocation
      test_url = site.sample
      puts 'Cracking '+test_url
      if !(testback = test_link(test_url))
        bogus_in << test_url
      elsif testback.class == String
        moved_in << test_url+' => '+testback
        test_url = testback
      end

      if recipe_url = (results = FinderServices.glean(test_url, site, 'URI')) && results.result_for('URI')
        found = found + 1
      else
        suspect << test_url
        recipe_url = test_url
      end

      # Probe the derived recipe URL for validity or relocation
      if recipe_url != test_url
        if !(testback = test_link(recipe_url))
          bogus_out << recipe_url
        elsif testback.class == String
          moved_out << recipe_url+' => '+testback
          recipe_url = testback
        end
      end

      # Check that the (possibly redirected) derived URL has a recipe on file
      if Recipe.where(:url => recipe_url)[0]
        puts 'URI matches recipe: '+recipe_url
        matched = matched + 1
      elsif (test_url != recipe_url) && Recipe.where(:url => test_url)[0]
        puts 'Unredirected URI matches recipe: '+test_url
        matched = matched + 1
      end

      if !site_map[site.id]
        puts "#{site.name} has no recipes"
        unmapped << "\t"+site.name
      end
    end
    puts "Found replacement for #{found} out of #{sought} URLs; result or default matched #{matched} times."
    puts "#{bogus_in.count} invalid links among the samples:"
    puts bogus_in.join("\n")
    puts "#{moved_in.count} redirected links among the samples:"
    puts moved_in.join("\n")
    puts "#{bogus_out.count} invalid links extracted:"
    puts bogus_out.join("\n")
    puts "#{moved_out.count} redirected links among the samples:"
    puts moved_out.join("\n")
    puts "#{suspect.count} samples that had no URL within:"
    puts suspect.join("\n")
    puts "#{unmapped.count} sites with no recipes:"
    puts unmapped.join("\n")
  end

=begin
  def self.extract_from_page url
    extractions = {}
    if !url.blank? && (site = Site.find_or_create url) && (ss = SiteServices.new(site))
      extractions = ss.extract_from_page url
    end
    extractions
  end
=end

  # Study a sample of every site for its response to extractions, summarizing the results
  # for every extraction strategy.
  def self.stab_at_samples limit=-1
    exclusions = %w{
       tname=copyright
      charset=UTF-8
      rel=stylesheet
    }
    f = File.open('stab.txt', 'w')
    summ = {'link' => {}, 'meta' => {}}
    nsites = 0
    Site.all.each { |site|
      next if site.recipes.count < 1
      self.new(site).stab_at_sample summ
      nsites += 1
      limit = limit - 1
      break if limit == 0
    }
    f = File.open('stabsumm.txt', 'w')
    summ.each { |k, v|
      f.puts k+':'
      v.each { |ik, iv|
        f.puts "\t#{ik}(#{iv.count}/#{nsites}):"
        iv.each { |iiv|
          f.puts '\t\t'+iiv
        }
      }
    }
    f.close
  end

  def stab_at_sample summ = {}
    puts "Processing Site #{@site.sample}"
    begin
      @nkdoc = Nokogiri::HTML(open @site.sample)
    rescue
      puts "Error: couldn't open page '#{@site.sample}' for analysis."
      recipe = @site.recipes_scope.first
      puts "Processing Recipe #{recipe.url}"
      begin
        @nkdoc = Nokogiri::HTML(open recipe.url)
      rescue
        puts "Error: couldn't open recipe '#{recipe.url}' for analysis."
        return {}
      end
    end
    candidates = summ.keys.collect { |key| @nkdoc.css(key) }.flatten
    candidates.each do |candidate|
      attribs = candidate.keys
      tag = candidate.name
      map = summ[tag]
      attribs.each { |attrib|
        next if attrib == 'href' || attrib == 'content'
        key_name_value = "#{attrib}=#{candidate.attributes[attrib].value}"
        remainder = (attribs - [attrib]).collect { |attrib| attrib+'='+candidate.attributes[attrib].value }
        (map[key_name_value] ||= []) << remainder.join('\t')
      }
    end
  end

=begin
  # Return the raw mapping from finders to arrays of hits
  def gleaning_results url, finders=nil
    PageTags.new(url, finders || FinderServices.applicable(@site), true, true).results
  end

  # Examine a page and return a hash mapping labels into found fields
  def extract_from_page(url, spec={})
    begin
      pagetags = PageTags.new(url, spec[:finders] || FinderServices.applicable(@site), spec[:all], false)
    rescue Exception => e
      puts "Error: couldn't open page '#{url}' for analysis."
      return {}
    end
    results = {}
    # We've cracked the page for all tags. Now report them into the result
    FinderServices.label_choices.each do |label|
      if foundstr = pagetags.result_for(label)
        # Assuming the tag was fulfilled, there may be post-processing to do
        case label
          when 'Title'
            # A title may produce both a title and a URL, conventionally separated by a tab
            titledata = foundstr.split('\t')
            results[:URI] = titledata[1] if titledata[1]
            foundstr = trim_title titledata.first
          when 'Image', 'URI'
            # Make picture path absolute if it's not already
            foundstr = resolve foundstr
        end
        results[label.to_sym] = foundstr
      end
    end
    results
  end
=end

  # Examine site names, possibly starting at a given id
  def self.names id=nil
    first_found = id.nil?
    nsites = Site.all.count
    site_n = 1
    Site.all.each do |site|
      name = site.name
      if (first_found ||= (site.id == id))
        puts "#{site_n}/#{nsites} >>>>>>>>>>>>>>>>>>>>>>"
        puts site.sample
        puts "\tid: #{site.id}"
        puts "\tname: #{name}"
        puts "\tdescription: #{site.description}"
        puts "\tlogo: #{site.logo}"
        begin
          okay_to_quit = true
          if site.ttlcut && site.ttlcut.match(site.name)
            puts "\tttlcut: #{site.ttlcut}"
            puts '...assuming name is okay'
          else
            puts 'Name? (blank to keep as is)'
            newname = gets.strip
            case newname
              when 'Q'
                return
              when /^D\s/
                site.description = newname.sub(/^D\s*/, '')
                puts "Saving Description \'#{site.description}\'"
                site.save
                okay_to_quit = false
              when /^L\s/
                site.logo = newname.sub(/^L\s*/, '')
                puts "Saving Logo \'#{site.logo}\'"
                site.save
                okay_to_quit = false
              else
                unless newname.blank?
                  site.name = newname
                  site.save
                end
            end
            return if newname == 'Q'
          end
        end until okay_to_quit
      else
        puts "...skipping #{name}..."
      end
      site_n += 1
    end
  end

  # Find sites that are candidates for merging, i.e. those with the same domain
  def similars
    Site.includes(:page_ref).
        joins(:page_ref).
        where("page_refs.domain = '#{site.page_ref.domain}'").
        uniq.
        to_a
  end

=begin
  def test_finders(url = nil)
    fr = FinderResults.new @site, site_finders
    fr.collect_results url || @site.sample
    self.site_finders = fr.revise_interactively
    case get_input('Any finder to add ([yY]: yes, [qQ]: quit without saving)? ')
      when 'y', 'Y'
        finder = {}
        finder.label = get_input('Label: ')
        finder[:selector] = get_input('Path: ')
        unless (attrib = get_input('Attribute: ')).blank?
          finder[:attribute_name] = attrib
        end
        ss.add_finder finder
      when 'q', 'Q'
        return
      else
        @site.save
    end
  end

  def add_finder (finder={})
    finder.each do |k, v|
      unless [:label, :selector, :attribute_name].include?(k)
        puts k.to_s+' is not a valid field'
        return
      end
      finder[k] = v.to_s
    end
    fr = FinderResults.new @site, [finder]
    fr.collect_results @site.sample
    self.site_finders = (self.site_finders + fr.revise_interactively)
    @site.save
  end

  # Examine every page on the site and count the number of hits on the global tag set
  def self.study(only = nil)
    # Get the set of tags to glean with
    fr = FinderResults.new Site.first, @@DefaultFinders.clone, only
    Site.all[100..110].each do |site|
      ss = self.new site
      puts '------------------------------------------------------------------------'
      puts 'home: '+site.home
      puts 'sample: '+site.sample
      if pagetags = fr.collect_results(site.sample, [:URI, :Title, :Image], true, site)
        puts '>>>>>>>>>>>>>>> Results >>>>>>>>>>>>>>>>>>'
        [:URI, :Title, :Image].each do |label|
          label = label.to_s
          result = (pagetags.result_for(label) || '** Nothing Found **')
          found_or_not = ''
          if label=='URI' && result!=site.sample
            found_or_not = '(NO MATCH!)'
          end
          puts label+found_or_not+': '+result
        end
      else
        puts '...No Results because couldn\t open pagetags to crack the page'
      end
    end
    # allfinders.sort { |t1,t2| t2[:count] <=> t1[:count] }.each { |tag| puts tag.to_s }
    puts '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! Report !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! '
    fr.report
    nil
  end

  # Go through all sites, presenting a sample recipe and querying the appropriateness
  # of all the associated finders.
  # If a site_id is provided, go through all sites starting with the one thus indicated.
  # If no site_id is provided, go through all unreviewed sites
  def self.screen site_id = nil
    @@DefaultFinders = @@DefaultFinders + @@CandidateFinders unless (@@DefaultFinders.last == @@CandidateFinders.last)
    if site_id
      site = Site.find(site_id)
      site.reviewed = false
      site.save
    end
    first_found = site_id.nil?
    (site_id ? Site.all : Site.where(reviewed: [false, nil] )).each do |site|
      if (first_found ||= (site.id == site_id))
        return if (site.reviewed = self.new(site).poll_extractions).nil?
        site.save if site.reviewed
      end
    end

    return if site_id
    Recipe.all.each do |recipe|
      unless (site = recipe.site).reviewed
        ss = self.new site
        return if (site.reviewed = ss.poll_extractions(recipe.url)).nil?
        return if (!site.reviewed) && (site.reviewed = ss.poll_extractions(recipe.url)).nil?
        site.save if site.reviewed
      end
    end
  end

  # Use the extant finders on a site, interactively querying their appropriateness and potentially assigning
  # results (either extractors or hard values) to the site
  def poll_extractions url=nil
    url ||= site.sample
    begin
      pagetags = PageTags.new(url, all_finders, true, false)
      correct_result = nil
      @site.finders.each do |finder|
        pagetags.results_for(finder[:id]).each do |result|
          # pagetags.results_for(label).each do |result|
          # finder = result.finder
          puts '<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<'
          puts "URL: #{url}"
          label = finder.label
          finder.each { |key, value| puts "\t(#{key}: #{value})" unless [:label, :count, :foundlings].include?(key) }
          # accepted = false
          if (foundstr = result.out.shift)
            unless column = correct_result && (foundstr == correct_result) && :yes_votes
              puts "#{label}: #{foundstr}"
              site_option = ['Description', 'Site Name', 'Title', 'Image', 'Author', 'Author Link', 'Tags'].include?(label) ? '" S(ave value to Site) ' : ''
              puts "Good? [y](es) n(o) #{site_option} Q(uit)"
              answer = gets.strip
              case answer[0]
                when 'Q'
                  return nil
                when 'N', 'n'
                  column = :no_votes
                  if answer[0] == 'N'
                    @site.reviewed = nil
                    @site.save
                    return false
                  end
                when 'Y', 'y', nil
                  column = :yes_votes
                  # accepted = (answer[0] == 'Y')
                  correct_result = foundstr
                  # Include the finder on the site
                  unless @site.finders.exists?(finder.slice :label, :selector, :attribute_name)
                    if existing = @site.finders.where(finder.slice :label).first
                      existing.selector = finder[:selector]
                      existing.attribute_name = finder[:attribute_name]
                      existing.save
                    else
                      @site.finders.create(finder.slice :label, :selector, :attribute_name)
                      @site.save
                    end
                  end
                  # Saved the title finder: take a crack at the editing RegExp
                  if label == 'Title'
                    done = false
                    until done
                      trimmed = trim_title foundstr
                      puts "Title In: #{foundstr}"
                      puts "Title Out: #{trimmed}"
                      puts 'Good? (sS to save, qQ to quit, otherwise type new regexp for title) '
                      answer = gets.strip
                      case answer
                        when 's', 'S'
                          site.save
                          done = true
                        when 'q', 'Q'
                          done = true
                        else
                          @site.ttlcut = answer
                      end
                    end
                  end
                when 'S'
                  # Copy the value to the corresponding field on the site
                  rest_of_line = answer[1..-1].strip
                  field_val = rest_of_line.blank? ? foundstr : rest_of_line
                  case label
                    when 'Image'
                      @site.logo = field_val
                      @site.save
                    when 'Description'
                      @site.description = field_val
                      @site.save
                    when 'Site Name', 'Title'
                      @site.name = field_val
                      @site.save
                    when 'Author'
                      TaggingServices.new(@site).tag_with field_val, User.super_id, type: 'Author'
                      @site.save
                    when 'Author Link'
                      # Add a reference to the author, if any
                      @site.tags(User.super_id, tagtype: 'Author').each { |author|
                        Reference.assert field_val, author, 'Home Page'
                      }
                    when 'Tags'
                      ts = TaggingServices.new @site
                      field_val.split(',').collect { |tagname|
                        tagname = tagname.split(':').last.strip
                        tagname if (tagname.length>0)
                      }.compact.each { |tagname|
                        ts.tag_with tagname, User.super_id
                      }
                    else
                      puts "There's no field on the site for #{label}"
                  end
              end
            end
            if column
              finder[column] = 0 unless finder[column]
              finder[column] = finder[column]+1
            end
          end
        end
      end
      return true
    rescue Exception => e
      puts "Error: couldn't open page '#{url}' for analysis:"
      puts e.to_s
      return false
    end
  end
=end
end

# Accumulates the results of a finder set
=begin
class FinderResults

  def initialize(site, finders, only=nil)
    @finders = finders
    @site = site
    finders.each do |finder|
      finder[:label] = finder[:label].to_s # Basic QA
      finder[:count] = 0 unless finder[:count]
      finder[:foundlings] = [] unless finder[:foundlings]
    end
    # Restrict the tags to the requested set, if any
    if only
      only.each_index { |ix| only[ix] = only[ix].to_s }
      @finders = @finders.select { |finder| only.include? finder[:label] }
    end
  end

  def collect_results(url, labelset=nil, verbose=true, site=nil)
    @site = site if site
    labelset ||= @site.finders.collect { |finder| finder[:label].to_s }.uniq
    begin
      # Collect all results from the page
      pagetags = PageTags.new url, SiteServices.new(@site).all_finders, true, verbose
    rescue
      puts "Error: couldn't open page '#{url}' for analysis."
      return nil
    end
    labelset.each do |label|
      pagetags.results_for(label = label.to_s).each do |result|
        foundset = '['+result.out.join("\n\t\t ")+'] (from '+url+')'
        finder = result.finder
        finder[:count] = finder[:count] + 1
        finder[:foundlings] << foundset
      end
    end
    return pagetags
  end

  # Interact via the terminal on the fate of the finders
  def revise_interactively
    @finders.each do |finder|
      puts "#{finder[:label]}: #{finder[:selector]}"
      finder.each { |key, value| puts "\t(#{key}: #{value})" unless [:label, :selector, :count, :foundlings].include?(key) }
      # Trim any found title using the 'ttlcut' attribute of the site
      if finder[:label] == 'Title' && @site.ttlcut
        finder[:foundlings].each_index do |ix|
          ttl, url = finder[:foundlings][ix].match(/^\[([^\]]*)\] \(from (.*)\)$/)[1, 2]
          finder[:foundlings][ix] = "[#{trim_title ttl}] (from #{url})"
        end
      end
      puts "\t["+finder[:foundlings].join("\n\t ")+"\t]"
      puts 'Action? ([dD]=Delete [qQ]=quit [C cutstring])'
      answer = gets.strip
      if m = answer.match(/^([Cc])\s*(\S.*$)/)
        answer, cutstring = m[1, 2]
      end
      case answer
        when 'd', 'D'
          @finders.delete_if { |f| f == finder }
          done = false
        when 'q', 'Q'
          exit
        when 'c', 'C'
          if finder[:label] == 'Title'
            puts "Really cut titles from this site using '#{cutstring}'?"
            if gets.strip == 'y'
              puts '...okay...'
              @site.ttlcut = cutstring
              done = false
            end
          end
        when ''
        else
          # Replace the path with input text
          puts "Really replace path '#{finder[:selector]}' with '#{answer}'?"
          next unless gets.strip == 'y'
          puts '...okay...'
          finder[:selector] = answer
          @finders.each do |tag|
            if tag == finder
              tag[:selector] = answer
            end
          end
          done = false
      end
    end
    @finders.each do |finder|
      finder.delete(:count)
      finder.delete(:foundlings)
    end
    @finders
  end

  def report
    # finderset = self.collect_tags(which)+@@TitleTags
    foundlist = {}
    @finders.each do |finder|
      path = finder[:selector]
      label = finder[:label]
      foundlist[label] ||= {}
      foundlist[label][path] ||= []
      foundlist[label][path] << finder
    end
    foundlist.each do |label, labelset|
      puts label.to_s+':'
      labelset.each do |path, pathset|
        puts "\t"+path+':'
        pathset.each do |tags|
          tags.each do |name, value|
            next if name == :label || name == :selector || name == :foundlings
            nq =  name.class == Symbol ? '\'' + name.to_s + '\'' : '"' + name + '"'
            vq = value.class == Symbol ? '\'' + value.to_s+ '\'' : '"' + value.to_s+'"'
            puts "\t\t"+nq+': '+vq
          end
          puts "\t\t"+tags[:foundlings].join("\n\t\t") if tags[:foundlings]
          puts "\t\t--------------------------------------"
        end
      end
    end
  end
end
=end
