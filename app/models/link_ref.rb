require 'uri'
# require 'CGI'

class LinkRef < ActiveRecord::Base
    belongs_to :link
    belongs_to :tag
    # before_save :ensure_unique
    
    # def ensure_unique
    # puts "Ensuring uniqueness of user #{self.user_id.to_s} to recipe #{self.recipe_id.to_s}"
    # end
    
    # Associate a link with a tag in the database. Parameters:
    #  :uristr
    #  :tag => if Tag class, taken as is
    #          if string, the tag's string (typed acc'ng to :tagtype)
    #          if integer, the tag's integer key
    #  resource_type :vendor, :store, :book, :blog, :rcpsite, :cookingsite, :othersite, :video, :glossary, :recipe
    #   :tagtype => integer or symbol for the tag's type (to assert new type on existing tag)
    # NB: URI and :key are both required    
    def self.associate (uristr, tag, opts = {} )
        puts "LinkRef.associate asserting #{tag} of type #{opts[:tagtype].to_s} for user #{opts[:userid].to_s}"
        resource_type = opts[:resource_type] || :glossary
        tag = Tag.assert_tag tag, tagtype: opts[:tagtype], userid: opts[:userid]
        puts "Associating tag #{tag.id.to_s} carrying links #{tag.link_ids.to_s}"
        link = Link.assert_link uristr, resource_type
        puts "...with link #{link.id.to_s} carrying tags #{link.tag_ids.to_s}"
        unless tag.link_ids.include? link.id
            puts "Adding link #{link.id} to tag #{tag.id}"
            tag.links << link
            tag.save
            puts "...tag now has links #{tag.link_ids.to_s}"
            puts "...and link now has #{link.tag_ids.to_s}"
            link.save
        end
        link
    end
        
require 'csv'
    def self.import_CSVfile(fname)
        rownum = 1
        CSV.foreach(fname, :encoding=>"UTF-8") do |row|
            return unless tagstrs = row[0]
            refpath = row[1]
            typestrs = row[2]
            uri = row[3]
            referents = [] # Clear the array specifying referents per type
            tags = [] # Clear the array of tags (one for each combo of string and type) for the line
            # In this first pass through the join of tags and types, we convert from strings to tags and typeids,
            #  meanwhile looking for a referent borne by one of the tags, which we will associate with all the
            #  tags in the second pass.
            tagstrs.split('; ').each do |tagstr|
                typestrs.split('; ').each do |typestr|
                    # puts self.associate :tag=>tag, :resource_type=>:glossary, :uri=>uri, :tagtype=>type, :userid=>superid
                    # Convert typestr to canonical form
                    if typeid = Tag.typenum(typestr)
                        # Tags will be asserted if they don't exist, assigned to the given type and made global
                        tag = Tag.assert_tag( tagstr, tagtype: typeid)
                        LinkRef.associate uri, tag
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
                        puts "Error on line ##{rownum.to_s}(#{row.to_s}): typeid '#{typestr}' isn't sensible"
                    end
                end
            end
            # Now we have a collection of tags, each with a given type. We may also have a referent for each type. 
            # In this pass, we associate all the tags of a given type with the common referent.
            tags.each do |tag|
                # Create a referent for this tag, if necessary
                if referent = referents[tag.tagtype]
                    # There is a target referent; assert it to the tag unless it's already there
                    referent.express(tag) # unless tag.referent_ids.include?(referent.id)
                else
                    referents[tag.tagtype] = Referent.express tag, tag.tagtype
                end
            end
            # Finally, we file the resulting referents under the given path
            referents.each_index do |ix| 
                if child = referents[ix]
                    pathlist = refpath.split('/').collect { |atom| Referent.express atom, ix }
                    # Now we have a series of referents representing the path above 'child'
                    # We establish the relationships by popping up the path
                    while parent = pathlist.pop
                        unless child.parents(true).any? { |otherparent| otherparent.id == parent.id }
                            child.parents << parent
                            child.save
                        end
                        child = parent
                    end
                end
            end
            rownum = rownum + 1
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
