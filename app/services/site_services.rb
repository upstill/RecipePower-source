class SiteServices
  attr_accessor :site

  def initialize site=nil
    @site = site
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
      site.trimmers.each do |trimmer|
        puts "Trimming with CSS selector #{trimmer}"
        @nkdoc.css(trimmer).map &:remove
      end if site.trimmers.present?
      @nkdoc.traverse do |node|
        # Ensure that link tags have a global url
        if node.element? && (node.name == 'a') && (url = node.attribute('href').to_s).present?
          absolute = safe_uri_join(site.home, url).to_s
          puts "'#{url}' absolutizes to '#{absolute}' in the context of '#{site.home}'"
          node.attribute('href').value = absolute if absolute != url
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
