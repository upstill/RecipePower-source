require 'yaml'
require 'nokogiri'
require 'uri'

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
    
    def initialize (nkdoc, site, ttlcut, ttlrepl)
        @nkdoc = nkdoc
        @site = site
        @ttlcut = ttlcut
        @ttlrepl = ttlrepl || ""
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
            puts "  #{label}:  "+str 
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
    attr_accessible :site, :home, :scheme, :subsite, :sample, :host, :port, :name, :logo, :tags_serialized
    
    # Virtual attribute tags is an array of specifications for finding a tag
    attr_accessor :tags
    
    before_save :pack_tags
    
    after_initialize :post_init
    
    @@TitleTags = [    # Used as last-ditch stab at getting a title
        { label: :Title, path: "#recipe_title" }, 
        { label: :Title, path: "#title" },
        { label: :Title, path: ".recipe .title" },
        { label: :Title, path: ".title a" },
        { label: :Title, path: ".fn" },
        { label: :Title, path: "title" } 
    ]
    
    def post_init
        unless self.site
            # We need to initialize the fields of the record, starting with site, based on sample
            if (link = self.sample) && (uri = URI(link))
                if uri.host.blank?
                    self.errors << "Can't make sense of URI"
                else
                    puts "Creating host matching #{uri.host} for #{link} with subsite \'#{self.subsite||""}\'"
        
                    # Reconstruct the sample from the link's path, query and fragment
                    self.sample = uri.path
                    self.sample << "?"+uri.query unless uri.query.blank?
                    self.sample << "#"+uri.fragment unless uri.fragment.blank?
        
                    # Define the site as the link minus the sample (sub)path
                    self.site = link[0,link.rindex(/#{self.sample}/) || link.length]
                    self.home = self.site # ...seems like a reasonable default...
        
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
        unpack_tags if !@tags
        @tags
    end
    
    def tags= (t)
        @tags = t
    end

    def pack_tags
        @tags = [ ] if !@tags
        self.tags_serialized = YAML::dump @tags
    end
    
    def unpack_tags
        pack_tags if !self.tags_serialized
        @tags = YAML::load self.tags_serialized
    end
    
    # Find and return the site wherein the named link is stored
    def self.by_link (link, *params)
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
            puts "Ill-formed link: "+link
            nil
        end
    end
    
    # Extract the key data from a page. page_type may specify what kind of page
    # (recipe, video, etc.) it's meant to be
    def crack_page (link, page_type = :Recipe)
        # Open the Nokogiri doc for the site
        pt = nil
        begin
            if (ou = open link) && (doc = Nokogiri::HTML(ou))
                pt = PageTags.new doc, self.site, self.ttlcut, self.ttlrepl
                pt.glean (self.tags.empty? ? Site.find(1).tags : self.tags)+@@TitleTags
                pt.hrecipe 
                ou.close 
            end
        rescue => e
            debugger
        end
        pt    
    end
    
    def fix_title(ttl)
        if self.ttlcut
            ttl.gsub! /#{self.ttlcut}/, (self.ttlrepl || '')
        end
        ttl.strip
    end
end
