# encoding: UTF-8
require 'yaml'
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

# PageTags accumulates the tags for a page
class PageTags 
    
  def initialize (nkdoc, site)
    @nkdoc = nkdoc
    @site = site
    @results = {}
  end
    
  # Return the entire set of tags found. This will be exactly the
  # tags that return non-nil from results() and result()
  def tags
    @results.keys
  end
  
  # Return the first result under the given label
  def result (label)
    (results = @results[label]) && # There are results for this tag
    (results = results.first) &&  # First hash in the list of results
    (results = results[:out]) && # Output result for this first hash
    results.first # First output
  end
  
  # Return the array of results under the given label
  def results (label = nil)
    if label
      (results = @results[label]) && # There are results for this tag
      (results = results.first) &&  # First hash in the list of results
      results[:out] # Output result for this first hash
    else # With no parameter, output a hash of results, one key=>first result
      out = {}
      @results.keys.each { |key|  out[key] = self.result key }
      out
    end
  end
  
protected
  # Extract the data from a node under the given label
  def tag (label, str, uri=nil)
    str = str.cleanup.remove_non_ascii
    unless str.blank?
      # Add to result
      str << '\t'+uri unless uri.blank?
      @result[:out] << str # Add to the list of results
    end
  end

  def glean_atag (label, atag, matchstr, cutstr)
    if href = atag.attribute("href")
      uri = href.value
      # puts "<a>"+atag.content+": "+uri+" --check against "+(matchstr || "<nil>")
      uri = @site+uri if uri =~ /^\// # Prepend domain/site to path as nec.
      outstr = atag.content
      outstr.gsub! /#{cutstr}/, '' if cutstr
      self.tag label, outstr, uri if uri =~ /#{matchstr}/ # Apply subsite constraint
    end
  end

  # Canonicalize strings by collapsing whitespace into a single space character, and
  # eliminating spaces immediately preceding commas
  def cleanupstr (str)
    str.strip.gsub(/\s+/, ' ').gsub(/ ,/, ',') unless str.nil?
  end
  
public
  
  def glean (tags)
    tags = [tags] if tags.class == Hash 
    tags.each do |tagspec|
      path = tagspec[:path]
      xpath = tagspec[:xpath]
      debugger if xpath
      next unless matches = (path && @nkdoc.css(path)) || (xpath && @nkdoc.xpath(xpath)) 
      next if matches.count < 1
      label = tagspec[:label]
      tomatch = tagspec[:linkpath]
      pattern = tagspec[:pattern]
      tocut = tagspec[:cut]
      @result = { out: [] } # For accumulating results
      matches.each do |ou|
        children = (ou.name == "ul") ? ou.css('li') : [ou]
        children.each { |child|
          # If the content is enclosed in a link, emit the link too
          if attrib = tagspec[:attribute] && child.attributes[tagspec[:attribute].to_s].to_s
            attrib.gsub! /#{tocut}/,'' if tocut 
            self.tag label, attrib # emit_to_data result, label, attrib
          elsif child.name == 'a'
            self.glean_atag label, child, tomatch, tocut # emit_atag_to_data result,  label, child, @site, tomatch, tocut
          elsif child.name == 'img'
            outstr = child.attributes['src'].to_s
            outstr.gsub! /#{tocut}/,'' if tocut 
            self.tag label, outstr unless pattern && !(outstr =~ /#{pattern}/)
            # emit_to_data result, label, outstr unless pattern && !(outstr =~ /#{pattern}/)
          # If there's an enclosed link coextensive with the content, emit the link
          elsif (atag = child.css("a").first) && (cleanupstr(atag.content) == cleanupstr(child.content))
            self.glean_atag label, atag, tomatch, tocut
            # emit_atag_to_data result, label, atag, @site, tomatch, tocut
          else # Otherwise, it's just vanilla content
            outstr = child.content
            outstr.gsub! /#{tocut}/,'' if tocut 
            self.tag label, outstr
            # emit_to_data result, label, outstr
          end
        }
      end
      unless @result[:out].join('').blank?
          # If we got results, report them
          @result[:in] = tagspec
          puts "...results due to #{tagspec}:"
          @result[:out].each { |str| puts "  #{label}:  "+str }
          @results[label] = @results[label] || []
          @results[label] << @result 
      end
    end        
  end
  # Parsing an hrecipe means following various paths
  def hrecipe # (pathsubs)
    hrFields = {
      ".cookingMethod" => :Process,
      ".cookingmethod" => :Process,
      ".ingredient" => :Ingredient,
      ".ingredient .name" => :Food,
      ".recipeCuisine" => :Genre,
      ".recipecuisine" => :Genre,
      ".recipeCategory" => :Course,
      ".recipecategory" => :Course,
      ".fn" => :Title,
      ".recipetype" => :Type,
      ".recipeType" => :Type
    }
    hrFields.keys.each do |path|
      label = hrFields[path]
      # path = pathsubs[label] || path
      self.glean ( { :path => ".hrecipe #{path}", :label=>label } )
    end
  end
end

class Site < ActiveRecord::Base
    attr_accessible :site, :home, :scheme, :subsite, :sample, :host, :name, :oldname, :port, :logo, :tags_serialized, :ttlcut, :ttlrepl
    
    belongs_to :referent
    
    has_many :feeds
    
    # Virtual attribute tags is an array of specifications for finding a tag
    attr_accessor :tags
    
    # When creating a site, also create a corresponding site referent
    # before_create :ensure_referent
    
    before_save :pack_tags
    
    after_initialize :post_init
    
    @@TitleTags = [    # Used as last-ditch stab at getting a title
        { label: :Title, path: "#recipe_title" }, 
        # { label: :Title, path: "#title" },
        { label: :Title, path: ".recipe .title" },
        # { label: :Title, path: ".title a" },
        # { label: :Title, path: ".fn" },
        { label: :Title, path: "title" } 
    ]
    
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
    
=begin
    # Use the site's name as a tag for creating a referent
    def ensure_referent
        self.referent = Referent.express(self.name, :Source)
    end
=end
    
    def post_init
      unless self.site
        # We need to initialize the fields of the record, starting with site, based on sample
        if urisq = URI::HTTP.sans_query(link = self.sample)
          if urisq.host.blank?
            self.errors << "Can't make sense of URI"
          else
            puts "Creating host matching #{urisq.host} for #{link} with subsite \'#{self.subsite||""}\'"
            puts "Link is '#{link}'; path is '#{urisq.path}'"
            # Define the site as the link minus the sample (sub)path
            self.site = link.sub(urisq.path, "")
            puts "...from which extracted site '#{self.site}'"
            self.home = self.site # ...seems like a reasonable default...

            # Reconstruct the sample from the link's path, query and fragment
            self.sample = urisq.path + link.sub(/^[^?]*/, "")

            # Save scheme, host and port information from the link parse
            self.scheme = urisq.scheme
            self.host = urisq.host
            self.port = urisq.port

            # Give the site a provisional name, the host name minus 'www.', if any
            self.name = urisq.host.sub(/www\./, '') unless self.oldname
          end
        else
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

    def pack_tags
        @tags = [] unless @tags || self.tags_serialized
        if @tags # @tags is nil iff tags never got unpacked
            self.tags_serialized = YAML::dump @tags
        end
    end
    
  def self.validate_link link
    link =~ URI::regexp(%w{ http https data })
  end
  
  # Try to make sense out of a given path in the context of another url.
  # Return either a valid URL or nil
  def self.valid_url(url, path)
    path ||= ""
    if self.validate_link(path) && good = self.test_link(path) # either the original URL or a replacement are good
      return (good.class == String) ? good : path
    elsif url
      # The path may be relative. In fact, it may have backup characters
      begin
        uri = URI.join( url, path ).to_s
        return self.validate_link(uri) && uri
      rescue Exception => e
        return nil
      end
    end
  end
    
  # Probe a URL with its server, returning the result code for a head request
  def self.header_result(link, resource=nil)
    begin
      url = resource ? URI.join(link, resource) : URI.parse(link)
      # Reject it right off the bat if the url isn't valid
      return 400 unless url.host && url.port
      
      req = Net::HTTP.new(url.host, url.port)
      code = req.request_head(url.path).code
      (code == "301") ? req.request_head(url.path).header["location"] : code.to_i
    rescue Exception => e
      # If the server doesn't want to talk, we assume that the URL is okay, at least
      return 401 if e.kind_of?(Errno::ECONNRESET) || url
    end
  end
    
    # Confirm that a proposed URL (with an optional subpath) actually has content at the other end
    # If the link is badly formed (returns a 400 result from the server) then we return false
    # If the resource has moved (result 301) and the new location works, we return the new link
    # Otherwise, we just return true. 
    # Thus: false means fail; string means good but moved; true means everything is copacetic
    def self.test_link(link, resource=nil)
      # If the result method can't make sense of the link, then give up
      return false unless result_code = self.header_result(link, resource)
      # Not very stringent: we only disallow ill-formed requests
      return (result_code != 400) unless result_code.kind_of? String
      
      # If the location has moved permanently (result 301) we try to supplant this link internally
      if (new_location = result_code) && (self.header_result(new_location) == 200)
        new_location
      else
        true
      end
    end
    
    # Find and return the site wherein the named link is stored
    def self.by_link (link)
      if (uri = URI::HTTP.sans_query(link)) && !uri.host.blank?
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
          if content.include?("RSS") || content.include?("rss") || href.match(/rss|feedburner|feedblitz/i)           
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
            if feed.validate
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
    
    def yield (name, url = nil)
      url = @crackedURL || self.sampleURL if url.blank?
      unless @pagetags && (url == @crackedURL) # Rebuild the found tags
        # Extract the key data from a page. page_type may specify what kind of page
        # (recipe, video, etc.) it's meant to be
        # Open the Nokogiri doc for the site
        @crackedURL = url
        @pagetags = nil
        begin
          ou = open url
          if ou && (doc = Nokogiri::HTML(ou))
            @pagetags = PageTags.new doc, self.site
            @pagetags.glean (self.tags.empty? ? Site.find_by_site('http://www.recipepower.com').tags : self.tags)+@@TitleTags
            # @pagetags.hrecipe 
            ou.close 
          end
        rescue => e
          x=2
        end
      end
      result = {}
      if (@pagetags && foundstr = @pagetags.result(name))
        # Assuming the tag was fulfilled, there may be post-processing to do
        case name
        when :Title
          titledata = foundstr.split('\t')
          result[:URI] = titledata[1]
          foundstr = self.trim_title titledata.first
        when :Image
          # Make picture path absolute if it's not already
          foundstr = self.site+foundstr unless foundstr =~ /^\w*:/
        end
        result[name] = foundstr
      end
      result
  end     
end
