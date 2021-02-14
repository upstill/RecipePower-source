class SiteServices
  attr_accessor :site

  def initialize site=nil
    @site = site
  end

  # Return a site (if any) that serves for the given link
  def self.find_for link
    return nil unless links = subpaths(link) # URL doesn't parse
    scope = Site.where root: links # Scope for all sites whose root matches a subpath of the url...
    # ...scan for the one with the longest root
    set = scope.to_a + SiteServices.unpersisted.values.find_all { |s| links.include? s.root }
    out = set.inject(set.first) do |result, site|
      site.root.length > result.root.length ? site : result
    end
    out
  end

  # Produce a Site that maps to a given url(s) whether one already exists or not
  def self.find_or_build_for url_or_page_ref
    link = url_or_page_ref.is_a?(PageRef) ? url_or_page_ref.url : url_or_page_ref
    # Look first for existing sites on any of the links
    if site = SiteServices.find_for(link)
      return site
    end

    if inlinks = subpaths(link)
      return SiteServices.find_or_build url_or_page_ref, root: inlinks.first, sample: link
    end
    SiteServices.find_or_build url_or_page_ref, sample: link
  end

  # Produce a Site for a given url(s) whether one already exists or not
  def self.find_or_build url_or_page_ref, options={}
    # If a PageRef is provided, and it bears the homelink, use that for our PageRef
    # to avoid an infinite regress of Site deriving PageRef deriving Site...
    if url_or_page_ref.is_a?(PageRef)
      homelink = host_url (options[:sample] ||= url_or_page_ref.url)
      if homelink == url_or_page_ref.url
        options[:page_ref] = url_or_page_ref
      else
        options[:home] = homelink
      end
      # options[:home] = (homelink == url_or_page_ref.url) ? url_or_page_ref : homelink
    else
      homelink = host_url (options[:sample] ||= url_or_page_ref)
      options[:home] = homelink
    end
    if options[:root] ||= cleanpath(homelink) # URL parses
      # Find a site, if any, based on the longest subpath of the URL
      if site = SiteServices.find_by_root(options[:root])
        return site # Can be found? Great!
      end
      # The home link needs to take heed of the root, since the latter may have a longer path
      if options[:home] && options[:root]&.match('/') # The root includes a path, so add it to :home
        options[:home] = safe_uri_join(options[:home], options[:root].sub(/[^\/]*\//, '')).to_s
      end
      # Need to make a new one. We'll leave this up to PageRef, which will do the actual work
      # of creating the site while managing indirects
      site = self.build_site options
      site.request_attributes :home
      return site
    end
  end

  def report_extractors *what
    # Provide a string suitable for giving to #assign_extractors to pass the site's :trimmers, :grammar_mods and :finders
    content_selector = site.finder_for('Content')&.selector || 'nil'
    puts "SiteServices.new(Site.find #{site.id}).adopt_extractors #{site.trimmers || '[]'}, '#{content_selector}', #{site.grammar_mods || '{}'}"
  end

  def adopt_extractors trimmers, content_selector=nil, grammar_mods
    site.trimmers = trimmers
    if content_selector
      f = site.finders.create_with(attribute_name: 'html', selector: content_selector).find_or_create_by label: 'Content'
      f.selector = content_selector
      f.save if f.content_selector_changed?
    end
  end

  # Evaluate the site's suitability for deletion
  def nuke_message button
    if site.recipes.exists? || site.feeds.exists?
      # No go: can't delete if there are feeds or recipes associated
      'NO DELETION: site contains recipes and/or feeds'
    elsif site.dependent_page_refs.exists?
      button + "CAUTION: site has #{labelled_quantity site.dependent_page_refs.count, 'page ref'} pointing to it, which will also be destroyed".html_safe
    else
      button
    end
  end
  
  # Used twice in sites.rake
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

  public

  # Make sure the given uri isn't relative, and make it absolute if it is
  def resolve(candidate)
    return candidate if candidate.blank? || (candidate =~ /^\w*:/)
    begin
      safe_uri_join(@site.home, candidate).to_s
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

  # For content derived from a recipe on the site, trim it to
  def trim_recipe content
    if content.present?
      @nkdoc = Nokogiri::HTML.fragment content
      # Remove nodes from the content according to the site's :trimmers collection
      trimmers = (site.trimmers || []) + ['script'] # Squash all <script> elements
      trimmers.each do |trimmer|
        puts "Trimming with CSS selector #{trimmer}"
        begin
          matches = @nkdoc.css trimmer # Protection against bad trimmer
        rescue Exception => exc
          raise exc, "CSS Selector (#{trimmer}) caused an error"
        end
        matches.map &:remove
      end
      @nkdoc.traverse do |node|
        # Ensure that link tags have a global url
        if node.element? && (node.name == 'a') && (url = node.attribute('href').to_s).present?
          absolute = safe_uri_join(site.home, url).to_s
          puts "'#{url}' absolutizes to '#{absolute}' in the context of '#{site.home}'"
          node.attribute('href').value = absolute if absolute != url
        elsif node.text?
          # Reduce all sequences of whitespace in text strings to either
          # 1) a single newline, if one appears in the string
          # 2) a single non-breaking space character, if one appears in the string
          # 3) a single blank
          node.content = node.content.deflate
        end
      end
      @nkdoc.to_html
    else
      content
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
    begin
      results = FinderServices.glean @site.home, @site
      results.labels.each { |label| puts "\t\t#{label}: #{results.result_for(label)}" }
    rescue Exception => msg
      puts '!!! Couldn\'t open the page for analysis!'
      breakdown = FinderServices.err_breakdown @site.home, msg
      @site.errors.add :url, breakdown[:msg]
      puts breakdown[:msg]
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

      if recipe_url = (results = FinderServices.glean(test_url, site, 'URI') rescue nil) && results.result_for('URI')
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
      rescue Exception => msg
        exc = Exception.new "Error: couldn't open recipe '#{recipe.url}' for analysis."
        exc.set_backtrace msg.backtrace
        raise exc # msg, breakdown[:msg] if dj
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

  private

  # In #find_or_build sometimes we need to find a site that has been priorly built but not yet persisted.
  # To make these as yet unpersisted sites findable, we keep a cache of unpersisted sites (the
  # hash @@UNPERSISTED, keyed on the root attribute).

  # Get the Site of the given root, including a search among unpersisted records
  def self.find_by_root root
    #SiteServices.unpersisted.find { |up| up.root == root } || Site.find_by(root: root)
    self.unpersisted[root] || Site.find_by(root: root)
  end

  def self.unpersisted
    (@@UNPERSISTED ||= {}).keep_if { |root, site| !site.persisted? }
      # @@UNPERSISTED.each { |root, site| @@UNPERSISTED.delete root if !site.persisted? }
  end

  # Build a new Site and add it to the unpersisted set
  def self.build_site options = {}
    # We need to get the site into the unpersisted table immediately, because
    # setting :home may create a page_ref, which may create another site
    self.unpersisted[options[:root]] = (site = Site.new root: options[:root])
    options.except(:root).each { |attr, val| site.send :"#{attr}=", val }
    site
  end

end
