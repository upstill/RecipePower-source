require './lib/Domain.rb'
require 'CGI'
require 'uri'

class LinkRef < ActiveRecord::Base
    belongs_to :link
    belongs_to :tag
    # before_save :ensure_unique
    
    # def ensure_unique
    # puts "Ensuring uniqueness of user #{self.user_id.to_s} to recipe #{self.recipe_id.to_s}"
    # end
    
    # The coder is used to encode/decode HTML
    @@coder = HTMLEntities.new
    
    # Associate a link with a tag in the database. Parameters:
    #  :uri
    #  :type => :vendor, :store, :book, :blog, :rcpsite, :cookingsite, :othersite, :video, :glossary
    #  :tag => if Tag class, taken as is
    #          if string, the tag's string (typed acc'ng to :keytype)
    #          if integer, the tag's integer key
    #   :tagtype => integer or symbol for the tag's type (iff :tag is string)
    # NB: URI and :key are both required    
    def self.associate (uri, tag, type = :glossary )
        # Find or create a matching link entry
        uri = @@coder.decode uri # Links are decoded in the database
        if type
            # Should be throwing an error if resource_type doesn't make sense
            resource_type = Link.resource_type_inDB type
            # Asserted type => type existing record if nil
            unless link = Link.find_by_uri_and_resource_type(uri, resource_type)
                link = Link.find_or_create_by_uri_and_resource_type(uri, nil)
                link.resource_type = resource_type
                link.save
            end
        else
            # No asserted type => Use existing record, if any
            link = Link.find_or_create_by_uri(uri)
        end
        # Get domain and path from url if not already there
        link.save if link.domain.nil? && (link.domain = domain_from_url(uri))
        
        # We have a link and a tag. Join the link to all tags which
        # match the tag name, modulo parametrization
        LinkRef.find_or_create_by_link_id_and_tag_id(link.id, tag.id) 
    end
    
require 'csv'
    def self.import_CSVfile(fname)
        CSV.foreach(fname, :encoding=>"UTF-8") do |row|
            return unless tagstrs = row[0]
            typestrs = row[1]
            uri = row[2]
            referents = [] # Clear the array specifying referents per type
            tags = [] # Clear the array of tags (one for each combo of string and type) for the line
            # In this first pass through the join of tags and types, we convert from strings to tags and typeids,
            #  meanwhile looking for a referent borne by one of the tags, which we will associate with all the
            #  tags in the second pass.
            tagstrs.split('; ').each do |tagstr|
                typestrs.split('; ').each do |typestr|
                    # puts self.associate :tag=>tag, :resource_type=>:glossary, :uri=>uri, :tagtype=>type, :userid=>superid
                    # Convert typestr to canonical form
                    typeid = Tag.tagtype_inDB typestr.capitalize
                    if typeid
                        tag = Tag.strmatch( tagstr, tagtype: typeid, force: true).first
                        LinkRef.associate uri, tag, :glossary
                        tags << tag
                        # The idea is to glean a common referent for all the tags of a given type. If none
                        #  exists among the incoming tags, then we'll make one later
                        if referentid = tag.referent_ids.first
                            # Tag has a referent!
                            # Check for clashing referents
                            if referents[typeid] && referents[typeid].id != referentid
                                puts "Clashing referents for #{tagstrs}: "
                                puts "\t"+referents[typeid].longname
                                puts "\t"+Referent.find(referentid).longname
                            else
                                referents[typeid] = Referent.find(referentid)
                            end
                        end
                    else
                        puts "Error: typeid '#{typestr}' isn't sensible"
                    end
                end
            end
            # Now we have a collection of tags, each with a given type. We may also have a referent for each type. 
            # In this pass, we associate all the tags of a given type with the common referent.
            tags.each do |tag|
                # Create a referent for this tag, if necessary
                if referent = referents[tag.tagtype]
                    # There is a target referent; assert it to the tag unless it's already there
                    referent.express(tag) unless tag.referent_ids.include?(referent.id)
                else
                    referents[tag.tagtype] = Referent.express(tag.name, tag.tagtype, true)
                end
            end
        end
    end
    def self.preview_CSVfile(fname)
        uses = {}
        CSV.foreach(fname, :encoding=>"UTF-8") do |row|
            foods = row[0]
            tagtypes = row[1]
            uri = row[2]
            # puts "#{foods}: #{tagtypes}\t#{uri}"
            foods.split('; ').each do |tag|
                sep = tag.split(',')
                tag = [sep.last.strip, sep.first.strip].join(' ') if sep.count > 1
                words = tag.split(' ')
                if words.count > 1
                    words.each do |word| 
                        if (word =~ /^\w/) && (word =~ /^\D/) && (word == word.capitalize)
                            line = "\t#{tag}: #{tagtypes} -- #{uri}" 
                            if uses[word]
                                uses[word] << line
                            else
                                uses[word] = [line]
                            end
                        end
                    end
                end
            end
        end
        File.open("words.txt", "w") do |f|
            uses.keys.sort.each do |word| 
                f.puts word
                uses[word].each { |use| f.puts use }
            end
        end        
    end
end
