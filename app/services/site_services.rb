require 'yaml'

class String
  def remove_non_ascii
    require 'iconv'
    # XXX Should be mapping single quotes into ASCII equivalent
    Iconv.conv('ASCII//IGNORE', 'UTF8', self)
  end

  def cleanup
    # self.strip.force_encoding('ASCII-8BIT').gsub(/[\xa0\s]+/, ' ').remove_non_ascii.encode('UTF-8').gsub(/ ,/, ',') unless self.nil?
    self.strip.force_encoding('ASCII-8BIT').remove_non_ascii.encode('UTF-8').gsub(/ ,/, ',') unless self.nil?
  end
end

class Result

  attr_accessor :finder, :out

  def initialize(f)
    @finder = f
    @out = []
  end

  # Extract the data from a node under the given label
  def push (str, uri=nil)
    str = str.cleanup.remove_non_ascii
    unless str.blank?
      # Add to result
      str << '\t'+uri unless uri.blank?
      self.out << str # Add to the list of results
    end
  end

  def found
    out.join('').length > 0
  end

  def report
    puts "...results due to #{@finder}:"
    puts "\t"+out.join("\n\t")
  end

  def is_for(label)
    @finder[:label] == label
  end

end

# Accumulates the results of a finder set
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
    labelset ||= @finders.collect { |finder| finder[:label].to_s }.uniq
    begin
      # Collect all results from the page
      pagetags = PageTags.new(url, @site, @finders, true, verbose)
    rescue
      puts "Error: couldn't open page '#{url}' for analysis."
      return nil
    end
    labelset.each do |label|
      pagetags.results_for(label = label.to_s).each do |result|
        foundset = "["+result.out.join("\n\t\t ")+"] (from "+url+")"
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
      puts "#{finder[:label]}: #{finder[:path]}"
      finder.each { |key, value| puts "\t(#{key}: #{value})" unless [:label, :path, :count, :foundlings].include?(key) }
      # Trim any found title using the 'ttlcut' attribute of the site
      if finder[:label] == "Title" && @site.ttlcut
        finder[:foundlings].each_index do |ix|
          ttl, url = finder[:foundlings][ix].match(/^\[([^\]]*)\] \(from (.*)\)$/)[1, 2]
          finder[:foundlings][ix] = "[#{trim_title ttl}] (from #{url})"
        end
      end
      puts "\t["+finder[:foundlings].join("\n\t ")+"\t]"
      puts "Action? ([dD]=Delete [qQ]=quit [C cutstring])"
      answer = gets.strip
      if m = answer.match(/^([Cc])\s*(\S.*$)/)
        answer, cutstring = m[1, 2]
      end
      case answer
        when "d", "D"
          @finders.delete_if { |f| f == finder }
          done = false
        when "q", "Q"
          exit
        when "c", "C"
          if finder[:label] == "Title"
            puts "Really cut titles from this site using '#{cutstring}'?"
            if gets.strip == 'y'
              puts "...okay..."
              @site.ttlcut = cutstring
              done = false
            end
          end
        when ""
        else
          # Replace the path with input text
          puts "Really replace path '#{finder[:path]}' with '#{answer}'?"
          next unless gets.strip == 'y'
          puts "...okay..."
          finder[:path] = answer
          @finders.each do |tag|
            if tag == finder
              tag[:path] = answer
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
      path = finder[:path]
      label = finder[:label]
      foundlist[label] ||= {}
      foundlist[label][path] ||= []
      foundlist[label][path] << finder
    end
    foundlist.each do |label, labelset|
      puts label.to_s+":"
      labelset.each do |path, pathset|
        puts "\t"+path+":"
        pathset.each do |tags|
          tags.each do |name, value|
            next if name == :label || name == :path || name == :foundlings
            nq = name.class == Symbol ? "\'"+name.to_s+"\'" : "\""+name+"\""
            vq = value.class == Symbol ? "\'"+value.to_s+"\'" : "\""+value.to_s+"\""
            puts "\t\t"+nq+": "+vq
          end
          puts "\t\t"+tags[:foundlings].join("\n\t\t") if tags[:foundlings]
          puts "\t\t--------------------------------------"
        end
      end
    end
  end
end

# PageTags accumulates the tags for a page
class PageTags

  private

  def initialize (url, site, finders, do_all=nil, verbose = true)
    @nkdoc = Nokogiri::HTML(open url)
    @finderset = finders
    @results = {}
    SiteServices.data_choices().each { |label| @results[label] = [] }
    @site = site
    @verbose = verbose
    # Initialize the results
    @finderset.each do |finder|
      label = finder[:label]
      next unless (do_all || @results[label].empty?) && (selector = finder[:path]) &&
          (matches = @nkdoc.css(selector)) &&
          (matches.count > 0)
      attribute_name = finder[:attribute]
      @result = Result.new finder # For accumulating results
      matches.each do |ou|
        children = (ou.name == "ul") ? ou.css('li') : [ou]
        children.each do |child|
          # If the content is enclosed in a link, emit the link too
          if attribute_value = attribute_name && child.attributes[attribute_name.to_s].to_s
            @result.push attribute_value
          elsif child.name == 'a'
            glean_atag finder, child
          elsif child.name == 'img'
            outstr = child.attributes['src'].to_s
            @result.push outstr unless finder[:pattern] && !(outstr =~ /#{finder[:pattern]}/)
            # If there's an enclosed link coextensive with the content, emit the link
          elsif (atag = child.css("a").first) && (cleanupstr(atag.content) == cleanupstr(child.content))
            glean_atag finder, atag
          else # Otherwise, it's just vanilla content
            @result.push child.content
          end
        end
      end
      if @result.found
        @result.report if @verboase
        @results[label] << @result
        @results[finder[:id]] = [@result]
      end
    end
  end

  def glean_atag (finder, atag)
    matchstr = finder[:linkpath]
    if href = atag.attribute("href")
      uri = href.value
      uri = @site+uri if uri =~ /^\// # Prepend domain/site to path as nec.
      outstr = atag.content
      @result.push outstr, uri if uri =~ /#{matchstr}/ # Apply subsite constraint
    end
  end

  # Canonicalize strings by collapsing whitespace into a single space character, and
  # eliminating spaces immediately preceding commas
  def cleanupstr (str)
    str.strip.gsub(/\s+/, ' ').gsub(/ ,/, ',') unless str.nil?
  end

  public

  # Return the first result under the given label
  def result_for (label)
    (results = @results[label]) && # There are results for this tag
        results.first && # First hash in the list of results
        results.first.out[0]
  end

  # Return the array of results under the given label
  def results_for (label)
    @results[label] || []
  end

end

class SiteServices
  attr_accessor :site

  def initialize site
    @site = site
    site_finders # Preload the finders
  end

  @@DefaultFinders = [
      {:label => "URI", :path => "link[rel='canonical']", :attribute => "href"},
      {:label => "URI", :path => "meta[property='og:url']", :attribute => "content"},
      {:label => "URI", :path => "div.post a[rel='bookmark']", :attribute => "href"},
      {:label => "URI", :path => ".title a", :attribute => "href"},
      {:label => "URI", :path => "a.permalink", :attribute => "href"},
      {:label => "Image", :path => "meta[itemprop='image']", :attribute => "content"},
      {:label => "Image", :path => "img.recipe_image", :attribute => "src"},
      {:label => "Image", :path => "img.mainIMG", :attribute => "src"},
      {:label => "Image", :path => "div.entry_content img", :attribute => "src"},
      {:label => "Image", :path => "img[itemprop='image']", :attribute => "src"},
      {:label => "Image", :path => "link[itemprop='image']", :attribute => "href"},
      {:label => "Image", :path => "link[rel='image_src']", :attribute => "href"},
      {:label => "Image", :path => "img[itemprop='photo']", :attribute => "src"},
      {:label => "Image", :path => ".entry img", :attribute => "src"},
      {:label => "Title", :path => "meta[name='title']", :attribute => "content"},
      {:label => "Title", path: "title"},
      {:label => "Title", :path => "meta[name='fb_title']", :attribute => "content"},
      {:label => "Title", :path => "meta[property='og:title']", :attribute => "content"},
      {:label => "Title", :path => "meta[property='dc:title']", :attribute => "content"},
  ]

  @@CandidateFinders = [
      {:label => "Author Name", path: "meta[name='author']", :attribute => "content"},
      {:label => "Author Name", path: "meta[itemprop='author']", :attribute => "content"},
      {:label => "Author Name", path: "meta[name='author.name']", :attribute => "content"},
      {:label => "Author Name", path: "meta[name='article.author']", :attribute => "content"},
      {:label => "Author Link", path: "link[rel='author']", :attribute => "href"},
      {:label => "Description", path: "meta[name='description']", :attribute => "content"},
      {:label => "Description", path: "meta[property='og:description']", :attribute => "content"},
      {:label => "Description", path: "meta[property='description']", :attribute => "content"},
      {:label => "Description", path: "meta[itemprop='description']", :attribute => "content"},
      {:label => "Tags", path: "meta[name='keywords']", :attribute => "content"},
      {:label => "Site Name", path: "meta[property='og:site_name']", :attribute => "content"},
      {:label => "Site Name", path: "meta[name='application_name']", :attribute => "content"},
  ]

#   @@DataChoices = [ "URI", "Image", "Title", "Description", "Author Name", "Author Link", "Site Name", "Keywords", "Tags" ]

  def self.data_choices
    @@DataChoices ||= (@@DefaultFinders.collect { |f| f[:label] } << "Site Logo").uniq
  end

  def self.attribute_choices
    @@AttributeChoices ||= @@DefaultFinders.collect { |f| f[:attribute] }.uniq
  end

  protected

  def default_finder?(tag)
    @@DefaultFinders.any? { |dt| dt == tag }
  end

  public

  def site_finders
    @site_finders ||=
        @site.finders.collect { |f| {:label => f.finds, :path => f.selector, :attribute => f.read_attrib, :id => f.id} }
    # result << {:label=>"Image", :path=>"p.bodytext img", :attribute=>"src"},
  end

  # Make sure the given uri isn't relative, and make it absolute if it is
  def resolve(candidate)
    return candidate if candidate.blank? || (candidate =~ /^\w*:/)
    begin
      URI.join(@site.site, candidate).to_s
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
      ttl.strip
    end
  end

  def get_input(prompt="? ")
    print prompt
    gets.strip
  end

  def test_finders(url = nil)
    fr = FinderResults.new @site, site_finders
    fr.collect_results url || @site.sampleURL
    self.site_finders = fr.revise_interactively
    case get_input("Any finder to add ([yY]: yes, [qQ]: quit without saving)? ")
      when "y", "Y"
        finder = {}
        finder[:label] = get_input("Label: ")
        finder[:path] = get_input("Path: ")
        unless (attrib = get_input("Attribute: ")).blank?
          finder[:attribute] = attrib
        end
        ss.add_finder finder
      when "q", "Q"
        return
      else
        @site.save
    end
  end

  def add_finder (finder={})
    finder.each do |k, v|
      unless [:label, :path, :attribute].include?(k)
        puts k.to_s+" is not a valid field"
        return
      end
      finder[k] = v.to_s
    end
    fr = FinderResults.new @site, [finder]
    fr.collect_results @site.sampleURL
    self.site_finders = (self.site_finders + fr.revise_interactively)
    @site.save
  end

  # Return the set of finders that apply to the site (those assigned to the site, then global ones)
  def all_finders
    # Give the DefaultFinders a unique id
    @@DefaultFinders.each { |df|
      df[:id] = Finder.where(finds: df[:label], selector: df[:path], read_attrib: df[:attribute]).first_or_create.id
    } unless @@DefaultFinders.first[:id]
    site_finders + @@DefaultFinders
  end

  def scrape
    extractions = extract_from_page(@site.sampleURL)
    puts "Site # #{@site.id.to_s}"
    puts "\tname: #{@site.name}"
    puts "\thome: (#{@site.home})"
    puts "\tsubsite: (#{@site.subsite})"
    puts "\tlogo: (#{@site.logo})"
    extractions.each { |k, v| puts "\t\t#{k.to_s}: #{v}" }
  end

  def self.purge do_it=false
    used_sites = Set.new(
      Recipe.all.collect { |r| r.site.id } +
      Reference.all.collect { |r| r.site.id } +
      Feed.all.collect { |f| f.site_id })
    Site.all.each { |site| site.destroy unless used_sites.include? site.id } if do_it
  end

  def self.scrape_for_feeds(n=-1)
    Site.all[0..n].each { |site| Delayed::Job.enqueue site }
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
      puts "---------------"
      sought = sought+1

      # Probe the site's sample URL for validity or relocation
      test_url = site.sampleURL
      puts "Cracking "+test_url
      if !(testback = test_link(test_url))
        bogus_in << test_url
      elsif testback.class == String
        moved_in << test_url+" => "+testback
        test_url = testback
      end

      ss = SiteServices.new site
      if ((results = ss.extract_from_page(test_url, :label => :URI, :finders => @@DefaultFinders)) && (recipe_url = results[:URI]))
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
          moved_out << recipe_url+" => "+testback
          recipe_url = testback
        end
      end

      # Check that the (possibly redirected) derived URL has a recipe on file
      if Recipe.where(:url => recipe_url)[0]
        puts "URI matches recipe: "+recipe_url
        matched = matched + 1
      elsif (test_url != recipe_url) && Recipe.where(:url => test_url)[0]
        puts "Unredirected URI matches recipe: "+test_url
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

  # Examine every page on the site and count the number of hits on the global tag set
  def self.study(only = nil)
    # Get the set of tags to glean with
    fr = FinderResults.new Site.first, @@DefaultFinders.clone, only
    Site.all[100..110].each do |site|
      ss = self.new site
      puts "------------------------------------------------------------------------"
      puts "home: "+site.home
      puts "site: "+site.site
      puts "sample: "+site.sampleURL
      if pagetags = fr.collect_results(site.sampleURL, [:URI, :Title, :Image], true, site)
        puts ">>>>>>>>>>>>>>> Results >>>>>>>>>>>>>>>>>>"
        [:URI, :Title, :Image].each do |label|
          label = label.to_s
          result = (pagetags.result_for(label) || "** Nothing Found **")
          found_or_not = ""
          if label=="URI" && result!=site.sampleURL
            found_or_not = "(NO MATCH!)"
          end
          puts label+found_or_not+": "+result
        end
      else
        puts "...No Results because couldn't open pagetags to crack the page"
      end
    end
    # allfinders.sort { |t1,t2| t2[:count] <=> t1[:count] }.each { |tag| puts tag.to_s }
    puts "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! Report !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! "
    fr.report
    nil
  end

  def self.extract_from_page(url, spec={})
    extractions = {}
    if !url.blank? && (site = Site.by_link url) && (ss = SiteServices.new(site))
      extractions = ss.extract_from_page url, spec
    end
    extractions
  end

  # Study a sample of every site for its response to extractions, summarizing the results
  # for every extraction strategy.
  def self.stab_at_samples limit=-1
    exclusions = %w{
       tname=copyright
      charset=UTF-8
      rel=stylesheet
    }
    f = File.open("stab.txt", "w")
    summ = {"link" => {}, "meta" => {}}
    nsites = 0
    Site.all.each { |site|
      next if site.recipes.count < 1
      self.new(site).stab_at_sample summ
      nsites += 1
      limit = limit - 1
      break if limit == 0
    }
    f = File.open("stabsumm.txt", "w")
    summ.each { |k, v|
      f.puts k+":"
      v.each { |ik, iv|
        f.puts "\t#{ik}(#{iv.count}/#{nsites}):"
        iv.each { |iiv|
          f.puts "\t\t"+iiv
        }
      }
    }
    f.close
  end

  def stab_at_sample summ = {}
    puts "Processing Site #{@site.sampleURL}"
    begin
      @nkdoc = Nokogiri::HTML(open @site.sampleURL)
    rescue
      puts "Error: couldn't open page '#{@site.sampleURL}' for analysis."
      recipe = @site.recipes.first
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
        next if attrib == "href" || attrib == "content"
        key_name_value = "#{attrib}=#{candidate.attributes[attrib].value}"
        remainder = (attribs - [attrib]).collect { |attrib| attrib+'='+candidate.attributes[attrib].value }
        (map[key_name_value] ||= []) << remainder.join("\t")
      }
    end
  end

  # Examine a page and return a hash mapping labels into found fields
  def extract_from_page(url, spec={})
    finders = spec[:finders] || all_finders
    if label = spec[:label] # Can specify either a single label or a set
      labels = ((label.class == Array) ? label : [label]).collect { |l| l.to_s }
      finders = finders.keep_if { |t| labels.include? t[:label] }
    else
      labels = SiteServices.data_choices
    end
    begin
      pagetags = PageTags.new(url, @site, finders, spec[:all], false)
    rescue
      puts "Error: couldn't open page '#{url}' for analysis."
      return {}
    end
    results = {}
    # We've cracked the page for all tags. Now report them into the result
    labels.each do |label|
      if foundstr = pagetags.result_for(label)
        # Assuming the tag was fulfilled, there may be post-processing to do
        case label
          when "Title"
            # A title may produce both a title and a URL, conventionally separated by a tab
            titledata = foundstr.split('\t')
            results[:URI] = titledata[1] if titledata[1]
            foundstr = trim_title titledata.first
          when "Image", "URI"
            # Make picture path absolute if it's not already
            foundstr = resolve foundstr
        end
        results[label.to_sym] = foundstr
      end
    end
    results
  end

  # Go through all sites, presenting a sample recipe and querying the appropriateness
  # of all the associated finders.
  def self.screen site_id = nil
    @@DefaultFinders = @@DefaultFinders + @@CandidateFinders unless (@@DefaultFinders.last == @@CandidateFinders.last)
    done_did = [] # Keep record of sites visited
    (site_id ? Site.where(id: site_id) : Site.where(reviewed: [false, nil] )).each do |site|
      return if (site.reviewed = self.new(site).poll_extractions).nil?
      site.save if site.reviewed
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
    url ||= site.sampleURL
    finders = all_finders
    begin
      pagetags = PageTags.new(url, @site, finders, true, false)
      correct_result = nil
      finders.each do |finder|
        pagetags.results_for(finder[:id]).each do |result|
          # pagetags.results_for(label).each do |result|
          # finder = result.finder
          puts "<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
          puts "URL: #{url}"
          label = finder[:label]
          finder.each { |key, value| puts "\t(#{key}: #{value})" unless [:label, :count, :foundlings].include?(key) }
          accepted = false
          while (foundstr = result.out.unshift) && !accepted
            unless column = correct_result && (foundstr == correct_result) && :yes_votes
              puts "#{label}: #{foundstr}"
              site_option = ["Description", "Site Name", "Title", "Image", "Author Name", "Author Link", "Tags"].include?(label) ? " S(ave value to Site) " : ""
              puts "Good? [y](es) n(o) #{site_option} Q(uit)"
              answer = gets.strip
              case answer[0]
                when 'Q'
                  return nil
                when 'N', 'n'
                  column = :no_votes
                when 'Y', 'y', nil
                  column = :yes_votes
                  accepted = (answer[0] == 'Y')
                  correct_result = foundstr
                  # Include the finder on the site
                  unless @site.finders.exists?(finds: finder[:label], selector: finder[:path], read_attrib: finder[:attribute])
                    if existing = @site.finders.where(finds: finder[:label]).first
                      existing.selector = finder[:path]
                      existing.read_attrib = finder[:attribute]
                      existing.save
                    else
                      @site.finders.create(finds: finder[:label], selector: finder[:path], read_attrib: finder[:attribute])
                      @site.save
                    end
                  end
                  # Saved the title finder: take a crack at the editing RegExp
                  if label == "Title"
                    done = false
                    until done
                      trimmed = trim_title foundstr
                      puts "Title In: #{foundstr}"
                      puts "Title Out: #{trimmed}"
                      puts "Good? (sS to save, qQ to quit, otherwise type new regexp for title) "
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
                    when "Image"
                      @site.logo = field_val
                      @site.save
                    when "Description"
                      @site.description = field_val
                      @site.save
                    when "Site Name", "Title"
                      @site.name = field_val
                      @site.save
                    when "Author Name"
                      TaggingServices.new(@site).tag_with field_val, tagger: User.super_id, type: "Author"
                      @site.save
                    when "Author Link"
                      # Add a reference to the author, if any
                      @site.tags(User.super_id, tag_type: "Author").each { |author|
                        Reference.assert field_val, author, "Home Page"
                      }
                    when "Tags"
                      ts = TaggingServices.new @site
                      field_val.split(',').collect { |tagname|
                        tagname = tagname.split(':').last.strip
                        tagname if (tagname.length>0)
                      }.compact.each { |tagname|
                        ts.tag_with tagname, tagger: User.super_id
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

end
