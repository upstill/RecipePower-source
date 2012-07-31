require 'yaml'
# require 'uri'
require 'open-uri'
require 'nokogiri'
require "net/http"

class String
    def remove_non_ascii
        require 'iconv'
        # XXX Should be mapping single quotes into ASCII equivalent
        Iconv.conv('ASCII//IGNORE', 'UTF8', self)
    end
    
    def cleanup
        self.strip.force_encoding('ASCII-8BIT').gsub(/[\xa0\s]+/, ' ').remove_non_ascii.encode('UTF-8').gsub(/ ,/, ',') unless self.nil?
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
    attr_accessible :site, :home, :scheme, :subsite, :sample, :host, :port, :name, :logo, :tags_serialized, :ttlcut, :ttlrepl, :site_referent
    
    belongs_to :referent
    
    # Virtual attribute tags is an array of specifications for finding a tag
    attr_accessor :tags
    
    # When creating a site, also create a corresponding site referent
    before_create :ensure_referent
    
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
    
    # Use the site's name as a tag for creating a referent
    def ensure_referent
        self.referent = Referent.express(self.name, :Source)
    end
    
    def post_init
        unless self.site
            # We need to initialize the fields of the record, starting with site, based on sample
            if (link = self.sample) && (uri = URI(link))
                if uri.host.blank?
                    self.errors << "Can't make sense of URI"
                else
                    puts "Creating host matching #{uri.host} for #{link} with subsite \'#{self.subsite||""}\'"
        
                    puts "Link is '#{link}'; path is '#{uri.path}'"
                    # Define the site as the link minus the sample (sub)path
                    self.site = link[0,(link =~ /#{uri.path}/) || link.length]
                    puts "...from which extracted site '#{self.site}'"
                    self.home = self.site # ...seems like a reasonable default...
        
                    # Reconstruct the sample from the link's path, query and fragment
                    self.sample = uri.path
                    self.sample << "?"+uri.query unless uri.query.blank?
                    self.sample << "#"+uri.fragment unless uri.fragment.blank?
        
                    # Save scheme, host and port information from the link parse
                    self.scheme = uri.scheme
                    self.host = uri.host
                    self.port = uri.port
        
                    # Give the site a provisional name, the host name minus 'www.', if any
                    self.name = uri.host.sub(/www\./, '') unless self.name
                end
            else
                # "Empty" site (probably defaults)
                self.site = ""
                self.subsite = ""
                self.name = "Anonymous" unless self.name
            end
            self.subsite = "" unless self.subsite
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
    
    def self.result(link, resource=nil)
      begin
        url = resource ? URI.join(link, resource) : URI.parse(link)
        req = Net::HTTP.new(url.host, url.port)
        req.request_head(url.path)
      rescue Exception => e
        return nil
      end
    end
    
    # Confirm that a proposed URL (with an optional subpath) actually has content at the other end
    # If the link is badly formed (returns a 400 result from the server) then we return false
    # If the resource has moved (result 301) and the new location works, we return the new link
    # Otherwise, we just return true. 
    # Thus: false means fail; string means good but moved; true means everything is copacetic
    def self.test_link(link, resource=nil)
      # If the result method can't make sense of the link, then give up
      return false unless res = self.result(link, resource)
      if res.code == "301"
          # If the location has moved permanently (result 301) we try to supplant this link internally
          if ((new_location = res.header["location"]) &&
              (res2 = self.result(new_location)) &&
              (res2.code == "200"))
            return new_location
          end
      end
      return res.code != "400" # Not very stringent: we only disallow ill-formed requests
    end
    
    # Find and return the site wherein the named link is stored
    def self.by_link (link)
        if (uri = URI(link)) && !uri.host.blank?
            # Find all sites assoc'd with the given domain
            sites = Site.where "host = ?", uri.host
            # It's possible that multiple sites may proceed from the same domain, 
            # so we need to find the one whose full site path (site+subste) matches the link
            # So: among matching hosts, find one whose 'site+subsite' is an initial substring of the link
            matching_subsite = matching_site = nil
            sites.each do |site|
                matching_site = site if link =~ /^#{site.site}/
                matching_subsite = site if link =~ /^#{site.site+site.subsite}/
            end
            matching_subsite || matching_site || Site.create(:sample=>link)
        else
            puts "Ill-formed link: '#{link}'"
            nil
        end
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
          # This could be a path relative to the home url
          begin
              uri = URI.link(path)
          rescue
              begin
                uri = URI.join( url, path) 
              rescue
                nil
              end 
          end
          uri && uri.to_s # Fix up relative paths to be absolute by prepending site URL
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
                if (ou = open url) && (doc = Nokogiri::HTML(ou))
                    @pagetags = PageTags.new doc, self.site
                    @pagetags.glean (self.tags.empty? ? Site.find_by_site('http://www.recipepower.com').tags : self.tags)+@@TitleTags
                    @pagetags.hrecipe 
                    ou.close 
                end
            rescue => e
                debugger
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
