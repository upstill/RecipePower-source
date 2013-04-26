# encoding: UTF-8
require 'yaml'
require './lib/uri_utils.rb'
require 'uri'
require 'open-uri'
require 'nokogiri'

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

# PageTags accumulates the tags for a page
class PageTags 
      
private
    
  def initialize (nkdoc, site, finders, do_all=nil)
    @finderset = finders
    @results = {}
    @finderset.collect { |finder| finder[:label] }.uniq.each { |label| @results[label] = [] }
    @nkdoc = nkdoc
    @site = site
    # Initialize the results
    @finderset.each do |tagspec|
      label = tagspec[:label]
      next unless @results[label].empty? && tagspec[:path] && 
                  (matches = @nkdoc.css(tagspec[:path])) && 
                  (matches.count > 0)
      attribute_name = tagspec[:attribute]
      @result = Result.new tagspec # For accumulating results
      matches.each do |ou|
        children = (ou.name == "ul") ? ou.css('li') : [ou]
        children.each do |child|
          # If the content is enclosed in a link, emit the link too
          if attribute_value = attribute_name && child.attributes[attribute_name.to_s].to_s
            @result.push attribute_value
          elsif child.name == 'a'
            glean_atag tagspec, child
          elsif child.name == 'img'
            outstr = child.attributes['src'].to_s
            @result.push outstr unless tagspec[:pattern] && !(outstr =~ /#{tagspec[:pattern]}/)
          # If there's an enclosed link coextensive with the content, emit the link
          elsif (atag = child.css("a").first) && (cleanupstr(atag.content) == cleanupstr(child.content))
            glean_atag tagspec, atag
          else # Otherwise, it's just vanilla content
            @result.push child.content
          end
        end
      end
      if @result.found
        @result.report
        @results[label] << @result 
      end
    end
  end

  def glean_atag (tagspec, atag)
    matchstr = tagspec[:linkpath]
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
    results.first &&  # First hash in the list of results
    results.first.out[0]
  end
  
  # Return the array of results under the given label
  def results_for (label)
    @results[label] || []
  end
  
end

class Site < ActiveRecord::Base
  include Taggable
    attr_accessible :site, :home, :scheme, :subsite, :sample, :host, :name, :oldname, :port, :logo, :tags_serialized, :ttlcut, :ttlrepl
    
    belongs_to :referent
    
    has_many :feeds
    
    # Virtual attribute tags is an array of specifications for finding a tag
    attr_accessor :tags
    
    # When creating a site, also create a corresponding site referent
    # before_create :ensure_referent
    
    before_save :pack_tags
    after_initialize :post_init

    @@DefaultTags = [
      {:label=>"URI", :path=>"link[rel='canonical']", :attribute=>"href" },
      {:label=>"URI", :path=>"meta[property='og:url']", :attribute=>"content" },
      {:label=>"URI", :path=>"div.post a[rel='bookmark']", :attribute=>"href"},
      {:label=>"URI", :path=>".title a", :attribute=>"href"},
      {:label=>"URI", :path=>"a.permalink", :attribute=>"href"},
      {:label=>"Image", :path=>"meta[property='og:image']", :attribute=>"content"}, 
      {:label=>"Image", :path=>"img.recipe_image", :attribute=>"src"}, 
      {:label=>"Image", :path=>"img.mainIMG", :attribute=>"src"}, 
      {:label=>"Image", :path=>"div.entry_content img", :attribute=>"src"}, 
      {:label=>"Image", :path=>"img[itemprop='image']", :attribute=>"src"}, 
      {:label=>"Image", :path=>"img[itemprop='photo']", :attribute=>"src"}, 
      {:label=>"Image", :path=>".entry img", :attribute=>"src"}, 
      {:label=>"Title", :path=>"meta[property='og:title']", :attribute=>:content}, 
      {:label=>"Title", :path=>"meta[property='dc:title']", :attribute=>:content}, 
      {:label=>"Title", :path=>"meta[name='title']", :attribute=>:content}, 
      {:label=>"Title", path: "title" },
    ]
=begin
http://d2k9njawademcf.cloudfront.net/slides/4973/original/032911F_570.JPG?1301453106
      {:label=>:Author, :path=>".hrecipe span.author"}, 
      {:label=>:Author, :path=>"meta[name='publisher']", :attribute=>:content}, 
      {:label=>:Author, :path=>"span[itemprop='author']"}, 
      {:label=>:Publication, :path=>"meta[name='publisher']", :attribute=>:content}, 
      {:label=>:Date, :path=>"div.post div.date"}, 
      {:label=>:Food, :path=>"#ingredients span[itemprop='ingredient'] span[itemprop='name']"}, 
      {:label=>:Food, :path=>"#ingredients span[rel='v:ingredient'] span[property='v:name']"}, 
      {:label=>:Food, :path=>".recipe-tags a"}, 
      {:label=>:Food, :path=>".recipeDetails li[itemprop='ingredient'] span[itemprop='name']"}, 
      {:label=>:Food, :path=>".recipeIngred span[itemprop='ingredient'] span[itemprop='name']"}, 
      {:label=>:Food, :path=>".tdm_recipe_ingredients li[itemprop='ingredients'] span.name"}, 
      {:label=>:Food, :path=>"li .ingredient .food"}, 
      {:label=>:Food, :path=>"li.ingredient .name"}, 
      {:label=>:Food, :path=>"span.recipe_structure_ingredients li[itemprop='ingredients']"}, 
      {:label=>:Food, :path=>"li.ingredient a"}, 
      {:label=>:Ingredient, :path=>"#ingredients span[itemprop='ingredient']"}, 
      {:label=>:Ingredient, :path=>"#ingredients span[rel='v:ingredient']"}, 
      {:label=>:Ingredient, :path=>"li[itemprop='ingredient']"}, 
      {:label=>:Ingredient, :path=>"li[itemprop='ingredients']"}, 
      {:label=>:Ingredient, :path=>"span[itemprop='ingredient']"}, 
      {:label=>:Ingredient, :path=>"p.ingredient"}, 
      {:label=>:Ingredient, :path=>"li.ingredient"}, 
      {:label=>:Publication, :path=>"meta[property='og:author']", :attribute=>:content}, 
      {:label=>:Tag, :path=>"#recipe-filedin"}, 
      {:label=>:Tag, :path=>"#recipe-info-attrs span.value"}, 
      {:label=>:Tag, :path=>".recipe-cats a"}, 
      {:label=>:Tag, :path=>"#recipeCategories .categories"}, 
      {:label=>:URI, :path=>"link[rel='canonical']", :attribute=>:href}, 
      {:label=>:URI, :path=>"meta[property='og:url']", :attribute=>:content}, 
      {:label=>:URI, :path=>"a.permalink", :attribute=>:href}, 
      {:label=>:URI, :path=>"#recipe_tab", :attribute=>:href}, 
      {:label=>:URI, :path=>".hrecipe a[rel='bookmark']", :attribute=>:href}, 
      {:label=>:URI, :path=>".post a[rel='bookmark']", :attribute=>:href}, 
      {:label=>:URI, :path=>"input[name='uri']", :attribute=>:value}
    ]
    
    @@TitleTags = [    # Used as last-ditch stab at getting a title
        { label: :Title, path: "#recipe_title" }, 
        # { label: :Title, path: "#title" },
        { label: :Title, path: ".recipe .title" },
        # { label: :Title, path: ".title a" },
        # { label: :Title, path: ".fn" },
        { label: :Title, path: "title" } 
    ]
=end
    
    def name
      (self.referent && referent.name) || oldname
    end
    
    def name=(str)
      self.oldname = str
      if referent
        referent.express(str, :tagtype => :Source)
      else
        self.referent = Referent.express(str, :Source)
      end
    end      
    
    def post_init
      unless self.site
        # We need to initialize the fields of the record, starting with site, based on sample
        # Ignore the query for purposes of gleaning the site
        if link = self.sample
          breakdown = link.match /(^[^?]*)(\?.*$)?/
          linksq, query = breakdown[1..2]
          begin
            urisq = URI linksq
          rescue Exception => e
            urisq = nil
          end
          if urisq && !urisq.host.blank?
            puts "Creating host matching #{urisq.host} for #{link} with subsite \'#{self.subsite||""}\'"
            puts "Link is '#{link}'; path is '#{urisq.path}'"
            # Define the site as the link minus the sample (sub)path
            self.site = linksq.sub(/#{urisq.path}$/, "")
            puts "...from which extracted site '#{self.site}'"
            self.home = self.site # ...seems like a reasonable default...

            # Reconstruct the sample from the link's path, query and fragment
            self.sample = urisq.path + (query || "")

            # Save scheme, host and port information from the link parse
            self.scheme = urisq.scheme
            self.host = urisq.host
            self.port = urisq.port.to_s

            # Give the site a provisional name, the host name minus 'www.', if any
            self.name = urisq.host.sub(/www\./, '') unless self.oldname
          else
            self.errors << "Can't make sense of URI"
          end
        end
        if !self.site
          # "Empty" site (probably defaults)
          self.site = ""
          self.subsite = ""
          self.name = "Anonymous" unless self.oldname
        end
        self.subsite ||= ""
      end
    end
    
    def tags
        @tags = @tags || self.tags_serialized ? YAML::load(self.tags_serialized) : []
    end
    
    def tags= (t)
        @tags = t
    end

    # Return the list of content finders for the site, in the order they should be applied
    def finders
      tags + @@DefaultTags # Any tags defined for this site get applied first
    end

    def pack_tags
        @tags = [] unless @tags || self.tags_serialized
        if @tags # @tags is nil iff tags never got unpacked
            self.tags_serialized = YAML::dump @tags
        end
    end
    
    def domain
      scheme+"://"+host+((port=="80") ? "" : (":"+port))
    end
    
    # Find and return the site wherein the named link is stored
    def self.by_link (link)
      # Sanitize the URL
      link.strip!
      link.gsub!(/\{/, '%7B')
      link.gsub!(/\}/, '%7D') 
      begin
        uri = URI link
      rescue Exception => e
        uri = nil
      end
      if uri && !uri.host.blank?
        # Find all sites assoc'd with the given domain
        sites = Site.where "host = ?", uri.host
        # If multiple sites may proceed from the same domain, 
        # we need to find the one whose full site path (site+subsite) matches the link
        # So: among matching hosts, find one whose 'site+subsite' is an initial substring of the link
        matching_subsite = matching_site = nil
        sites.each do |site|
          unless site.site.empty?
            matching_site = site if link.index(site.site)
            matching_subsite = site if !site.subsite.empty? && link.index(site.site+site.subsite)
          end
        end
        matching_subsite || matching_site || Site.create(:sample=>link)
      else
        puts "Ill-formed link: '#{link}'"
        nil
      end
    end
    
    # Scour the set of sites for feeds. Summarize the found sets.
    def self.scrapefeeds(n = -1)
      count = skunked = added = feedcount = 0
      rejects = []
      Site.all.each { |site|
        count = count+1
        next if site.feeds.count > 0
        added = added - site.feeds.count
        rejects = rejects + site.feedlist
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
    
    # Check the page given for feeds
    def self.feedlist(url)
      if site = self.by_link(url)
        site.feedlist url
      end
    end
    
    # Examine the sample page of a site (or a given other page) for RSS feeds
    def feedlist(page_url=nil)
      rejects = []
      ((page_url && [page_url]) || [sampleURL, home]).each do |page_url|
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
              self.feeds << feed 
            else
              rejects << "#{feed.url} (from #{page_url})"
            end
          end
        end
      end
      rejects
    end
    
     # Return a list of image URLs for a given page
    def self.piclist(url)
      begin 
        return [] unless (ou = open url) && (site = Site.by_link url) && (doc = Nokogiri::HTML(ou))
      rescue Exception => e
        return []
      end
      # Get all the img tags, uniqify them, purge non-compliant ones and insert the domain as required
      doc.css("img").map { |img| 
        img.attributes["src"] # Collect all the "src" attributes from <img tags
      }.compact.map { |src| # Ignore if nil
        src.value # Extract value (URL string)
      }.uniq.keep_if { |url| # Purge duplicates
        url =~ /\.(gif|tif|tiff|png|jpg|jpeg|img)$/i # Accept only image tags
      }.map{ |path| 
        begin
          (uri = URI.join( url, path)) && uri.to_s 
        rescue Exception => e
          nil
        end 
      }.compact
    end
    
    # Doctor a scanned title coming in from a web page, according to the site parameters
    def trim_title(ttl)
      if ttl
        unless self.ttlcut.blank?
          ttl.gsub! /#{self.ttlcut}/i, (self.ttlrepl || '')
        end
        ttl.strip
      end
    end
    
    def sampleURL
        self.site+(self.sample||"")
    end

private    
    def page_tags(url, tags, do_all)
      begin
        ou = open url
      rescue Exception => e
        puts "!!! Exception fetching page "+url
        return nil
      end
      
      begin
        doc = Nokogiri::HTML(ou)
      rescue Exception => e
        puts "!!! Exception loading #{url} into Nokogiri"
        ou.close
        return nil
      end
      
      begin
        @pagetags = PageTags.new doc, site, tags, do_all
      rescue Exception => e
        puts "!!! Exception opening PageTags on "+url
        ou.close
        return {}
      end
    end
    
public

  # Make sure the given uri isn't relative, and make it absolute if it is
  def make_link_absolute(candidate)
    (candidate =~ /^\w*:/) ? candidate : site+candidate
  end
  
  def self.extract_from_page(url)
    if !url.blank? && (site = self.by_link url)
      site.extract_from_page url
    end
  end
    
    # Examine a page and return a hash mapping labels into found fields
    def extract_from_page(url, spec={})
      tags = spec[:tags] || finders
      if label = spec[:label] # Can specify either a single label or a set
        labels = ((label.class == Array) ? label : [label]).collect { |l| l.to_s }
        tags = tags.keep_if { |t| labels.include? t[:label] }
      else
        labels = tags.collect { |tag| tag[:label].to_s }.uniq
      end
      results = {}
      
      if @pagetags = page_tags(url, tags, spec[:all])
        # We've cracked the page for all tags. Now report them into the result
        labels.each do |label|
          if foundstr = @pagetags.result_for(label)
            # Assuming the tag was fulfilled, there may be post-processing to do
            case name
            when "Title"
              titledata = foundstr.split('\t')
              result["URI"] = titledata[1]
              foundstr = self.trim_title titledata.first
            when "Image", "URI"
              # Make picture path absolute if it's not already
              foundstr = self.site+foundstr unless foundstr =~ /^\w*:/
            end
            results[label.to_sym] = foundstr
          end
        end
      end
      results
    end
=begin
    def yield (name, url)
      unless @pagetags && (url == @crackedURL) # Rebuild the found tags
        # Extract the key data from a page. page_type may specify what kind of page
        # (recipe, video, etc.) it's meant to be
        # Open the Nokogiri doc for the site
        @crackedURL = url
        @pagetags = nil
        begin
          # puts "\tRequesting page "+url
          ou = open url
          # puts "\t...going into Nokogiri..."          
          if ou && (doc = Nokogiri::HTML(ou))
            # puts "\t...running PageTags..."
            @pagetags = PageTags.new doc, site, finders
            # puts "\t...finished PageTags..."
            # @pagetags.glean
            ou.close 
          end
        rescue => e
          x=2
        end
      end
      result = {}
      if (@pagetags && foundstr = @pagetags.result_for(name))
        # Assuming the tag was fulfilled, there may be post-processing to do
        case name
        when "Title"
          titledata = foundstr.split('\t')
          result["URI"] = titledata[1]
          foundstr = self.trim_title titledata.first
        when "Image", "URI"
          # Make picture path absolute if it's not already
          foundstr = self.site+foundstr unless foundstr =~ /^\w*:/
        end
        result[name] = foundstr
      end
      result
  end     
=end
  
  def self.all_tags(which=nil)
    which = which.to_s if which
    tagset = []
    Site.all.map(&:tags).each do |tagspecs| 
      tagspecs.each do |tagspec|
        tagspec.each { |key, value| tagspec[key] = value.to_s }
        next if (which && (tagspec[:label] != which)) || tagset.any? { |candidate| tagspec == candidate }
        tagset << tagspec
      end
    end
    tagset
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
      end
    end
    sought = found = matched = 0
    suspect = []
    bogus_in = []
    moved_in = []
    bogus_out = []
    moved_out = []
    self.all.each do |site| 
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
      
      if( (results = site.extract_from_page(test_url, :label => :URI, :tags => @@DefaultTags )) && (recipe_url = results[:URI]))
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
=begin
      else
        puts "!!!! URI for site #{site.home} not found among recipes:"
        puts "SampleURL: "+site.sampleURL
        puts "Redirected:"+test_url
        puts "Extracted: "+recipe_url
        stripped_host = (site.host =~ /^www./) ? site.host[4..-1] : site.host
        recipes = Recipe.where("url LIKE ?", "%"+stripped_host+"%") # + site_map[site.id]
        if recipes.count > 0
          recipes.each { |recipe| puts "\t"+recipe.url }
        else
          puts "...no recipes found for query url LIKE \'%"+stripped_host+"%\'"
        end
=end
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
  end
  
  # Examine every page on the site and count the number of hits on the global tag set
  def self.study(only = nil)
    # Get the set of tags to glean with
    alltags = @@DefaultTags # self.all_tags
    # Initialize the counts to zero
    alltags.each { |tag| tag[:label] = tag[:label].to_s; tag[:count] = 0 }
    # Restrict the tags to the requested set, if any
    if only
      alltags = alltags.select { |tag| only.include? tag[:label] }
    end
    self.all.each do |site|
      puts "------------------------------------------------------------------------"
      puts "home: "+site.home
      puts "site: "+site.site
      puts "sample: "+site.sampleURL
      if @pagetags = page_tags(site.sampleURL, alltags)
        puts ">>>>>>>>>>>>>>> Results >>>>>>>>>>>>>>>>>>"
        [:URI,:Title,:Image].each do |label|
          label = label.to_s
          next if only && !only.include?(label) 
          @pagetags.results_for(label).each do |result| 
            finder = result.finder
            finder[:count] = finder[:count] + 1 
            foundset = "["+result.out.join("\n\t\t ")+"] (from "+site.sampleURL+")"
            if finder[:foundlings]
              finder[:foundlings] << foundset
            else
              finder[:foundlings] = [foundset]
            end            
          end
          result = (@pagetags.result_for(label) || "** Nothing Found **")
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
    # alltags.sort { |t1,t2| t2[:count] <=> t1[:count] }.each { |tag| puts tag.to_s }
    puts "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! Report  !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! "
    # self.show_tags( alltags.sort { |t1,t2| t2[:count] <=> t1[:count] } )
    self.show_tags( alltags )
    nil
  end

  def self.show_tags(tagset)
    # tagset = self.collect_tags(which)+@@TitleTags
    alltags = {}
    tagset.each do |tag|
      path = tag[:path]
      label = tag[:label]
      alltags[label] ||= {}
      alltags[label][path] ||= []
      alltags[label][path] << tag
    end
    alltags.each do |label, labelset|
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

=begin
Title:
	title:
		'cut': " - Calabria from scratch"
		'count': "269"
		--------------------------------------
		'cut': "spicy icecream: "
		'count': "269"
		--------------------------------------
		'cut': " Recipe \| Steamy Kitchen Recipes"
		'count': "269"
		--------------------------------------
		'cut': " \| RecipeGirl.com"
		'count': "269"
		--------------------------------------
		'count': "269"
		--------------------------------------
	meta[property='og:title']:
		'attribute': "content"
		'count': "122"
		--------------------------------------
		'attribute': "content"
		'cut': " - Drink Recipe.*"
		'count': "122"
		--------------------------------------
		'attribute': "content"
		'cut': "Recipe: "
		'count': "122"
		--------------------------------------
		'attribute': "content"
		'cut': " Recipe.*$"
		'count': "122"
		--------------------------------------
		'attribute': "content"
		'cut': "How to Make.*- "
		'count': "122"
		--------------------------------------
		'attribute': "content"
		'cut': "IDEAS IN FOOD: "
		'count': "122"
		--------------------------------------
		'attribute': "content"
		'cut': " recipe"
		'count': "122"
		--------------------------------------
	.fn:
		'count': "96"
		--------------------------------------
	span.fn:
		'count': "55"
		--------------------------------------
	tr td div:
		'count': "52"
		--------------------------------------
	.title a:
		'count': "36"
		--------------------------------------
	h1.title:
		'count': "28"
		--------------------------------------
	meta[name='title']:
		'attribute': "content"
		'count': "22"
		--------------------------------------
	h2 a[rel='bookmark']:
		'count': "13"
		--------------------------------------
	div.post h2 a[rel='bookmark']:
		'count': "11"
		--------------------------------------
	#title:
		'count': "11"
		--------------------------------------
	h3.entry-title a:
		'count': "7"
		--------------------------------------
	meta[property='dc:title']:
		'attribute': "content"
		'count': "3"
		--------------------------------------
	.recipe .title:
		'count': "3"
		--------------------------------------
	#zlrecipe-title:
		'count': "2"
		--------------------------------------
	.storytitle:
		'count': "2"
		--------------------------------------
	#recipe_title:
		'count': "1"
		--------------------------------------
	#page-title-link:
		'count': "1"
		--------------------------------------
	#main-article-info h1:
		'cut': " recipe"
		'count': "1"
		--------------------------------------
	#maincontent .content h2 a[rel='bookmark']:
		'count': "1"
		--------------------------------------
	#article-body-blocks h2:
		'count': "0"
		--------------------------------------
Image:
	img:
		'count': "261"
		--------------------------------------
	meta[property='og:image']:
		'attribute': "content"
		'count': "113"
		--------------------------------------
	img.photo:
		'count': "63"
		--------------------------------------
	div.entry-content a img:
		'count': "50"
		--------------------------------------
	table img:
		'attribute': "alt"
		'count': "44"
		--------------------------------------
	img.size-full:
		'count': "38"
		--------------------------------------
	.entry img:
		'count': "36"
		--------------------------------------
	img.aligncenter:
		'count': "29"
		--------------------------------------
	.post-body img:
		'count': "20"
		--------------------------------------
	img[itemprop='image']:
		'attribute': "src"
		'count': "15"
		--------------------------------------
		'count': "15"
		--------------------------------------
	div.post div.entry a:first-child img:first-child:
		'count': "14"
		--------------------------------------
	img[itemprop='photo']:
		'count': "5"
		--------------------------------------
	div.holder img:
		'count': "4"
		--------------------------------------
	img.recipe_image:
		'count': "2"
		--------------------------------------
	a#recipe-image:
		'attribute': "href"
		'count': "1"
		--------------------------------------
	div.featRecipeImg img:
		'count': "1"
		--------------------------------------
	div.photo img[itemprop='image']:
		'count': "1"
		--------------------------------------
	#drink_infopicvid img:
		'count': "1"
		--------------------------------------
	.listing-photo img:
		'count': "1"
		--------------------------------------
	a[rel='modal-recipe-photos'] img:
		'count': "1"
		--------------------------------------
	.hfeed .featured-img img:
		'count': "1"
		--------------------------------------
	.storycontent img:
		'count': "1"
		--------------------------------------
	#picture img:
		'count': "1"
		--------------------------------------
	#recipe-image:
		'attribute': "href"
		'count': "1"
		--------------------------------------
	#main-content-picture img:
		'count': "1"
		--------------------------------------
	div.box div.post div.entry a img:
		'attribute': "src"
		'count': "1"
		--------------------------------------
	.landscape-image img:
		'count': "1"
		--------------------------------------
	#rec-photo img:
		'count': "0"
		--------------------------------------
	link[rel='image_source']:
		'attribute': "href"
		'count': "0"
		--------------------------------------
	img#photo-target:
		'count': "0"
		--------------------------------------
	img.mainIMG:
		'count': "0"
		--------------------------------------
	#photo-target:
		'count': "0"
		--------------------------------------
	.tdm_recipe_image img[itemprop='image']:
		'attribute': "src"
		'count': "0"
		--------------------------------------
	div.recipe-image-large img:
		'count': "0"
		--------------------------------------
	td img:
		'pattern': "images/food/"
		'count': "0"
		--------------------------------------
URI:
	link[rel='canonical']:
		'attribute': "href"
		'count': "170"
		--------------------------------------
	meta[property='og:url']:
		'attribute': "content"
		'count': "114"
		--------------------------------------
	.post a[rel='bookmark']:
		'attribute': "href"
		'count': "46"
		--------------------------------------
	.title a:
		'attribute': "href"
		'count': "37"
		--------------------------------------
	input[name='uri']:
		'attribute': "value"
		'count': "17"
		--------------------------------------
	div.post h2 a[rel='bookmark']:
		'attribute': "href"
		'count': "11"
		--------------------------------------
	a.permalink:
		'attribute': "href"
		'count': "10"
		--------------------------------------
	a.addthis_button_pinterest:
		'attribute': "pi:pinit:url"
		'count': "3"
		--------------------------------------
	.hrecipe a[rel='bookmark']:
		'attribute': "href"
		'count': "3"
		--------------------------------------
	#recipe_tab:
		'attribute': "href"
		'count': "2"
		--------------------------------------
	div.hrecipe a[rel='bookmark']:
		'attribute': "href"
		'count': "1"
		--------------------------------------
=end