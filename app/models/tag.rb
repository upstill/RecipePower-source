# encoding: UTF-8
class Tag < ActiveRecord::Base
    # require 'iconv'
    include Typeable
    
    typeable( :tagtype, 
        Untyped: ["Untyped", 0 ],
        Genre: ["Genre", 1], 
        Role: ["Role", 2], 
        Process: ["Process", 3], 
        Ingredient: ["Ingredient", 4], 
        Unit: ["Unit", 5], 
        Source: ["Source", 6], 
        Author: ["Author", 7], 
        Occasion: ["Occasion", 8], 
        PantrySection: ["Pantry Section", 9], 
        StoreSection: ["Store Section", 10], 
        Channel: ["Channel", 11], 
        Tool: ["Tool", 12], 
        Nutrient: ["Nutrient", 13], 
        CulinaryTerm: ["Culinary Term", 14]
    )
    
    attr_accessible :name, :id, :tagtype, :isGlobal, :links, :recipes, :referents, :users, :owners, :primary_meaning
    
    # tagrefs associate tags with recipes
    #  has_many :tagrefs
    # has_many :recipes, :through=>:tagrefs
    has_many :taggings, :dependent => :destroy
    # has_many :recipes, :through => :taggings, :class_name => "Recipe"
    
    # expressions associate tags with the foods (roles, processes, etc.) they refer to
    # These are the "meanings" of a tag
    has_many :expressions
    has_many :referents, :through=>:expressions
    
    # The primary meaning is the default meaning of a tag
    belongs_to :primary_meaning, :class_name => "Referent", :foreign_key => "referent_id"
    
    # linkrefs give access to glossary entries, etc.
    # has_many :link_refs
    # has_many :links, :through=>:link_refs
    
    # ownership of tags restrict visible tags
    has_many :tag_owners
    has_many :owners, :through=>:tag_owners, :class_name => "User", :foreign_key => "user_id"
    
    validates_presence_of :name
    before_validation :tagqa
    
    # Pre-check to determine whether a tag can absorb another tag
    def can_absorb other
        other.normalized_name == self.normalized_name && ((other.tagtype==0) || (other.tagtype == self.tagtype))    
    end
    
    def recipes(uid=nil)
      Recipe.where id: recipe_ids(uid)
    end
    
    def recipe_ids(uid=nil)
      constraints = { tag_id: id, entity_type: "Recipe" }
      constraints[:user_id] = uid if uid
      Tagging.where(constraints).map &:entity_id
    end
    
    def users(uid=nil)
      User.where id: user_ids(uid)
    end
    
    def user_ids(uid=nil)
      constraints = { tag_id: id, entity_type: "User" }
      constraints[:user_id] = uid if uid
      Tagging.where(constraints).map &:entity_id
    end
    
    # Eliminate the tag of the given id, replacing it with this one
    def absorb oldid
        t2 = Tag.find oldid
        return false unless can_absorb t2
        newid = self.id
        # Only consider absorbing tags of non-clashing type
        ownerids = self.owner_ids
            
        # Absorb recipe taggings (Tagrefs) by replacing references to t2 with this id, avoiding duplication
=begin
        rids = self.recipe_ids
        t2.tagrefs.each do |tr| 
            # Do nothing if this recipe is already listed under the new tag
            unless rids.include? tr.recipe_id 
                tr.tag_id = newid
                tr.save
            end
            # Make sure the owner of the link can see the replaced link
            admit_user tr.owner_id
        end
=end
        self.recipes = (self.recipes + t2.recipes).uniq
        
        # Merge owners by taking on all owners of the absorbee
        # t2.owner_ids.each { |uid| admit_user uid }
        self.owners = self.owners + t2.owners
        
        # Replace referents' DIRECT use of the tag
        Referent.where(tag_id: oldid).each do |ref| 
            ref.tag_id = newid # Now it's all about ME ME ME
            ref.save
        end
        
        # Replace the use of the tag in expressions
=begin
        myrefids = self.referent_ids
        Expressions.where(tag_id: oldid).each do |expr|
            # If we're not already linked to the referent, do so now
            unless myrefids.include?(expr.referent_id) 
                expr.tag_id = newid
                expr.save
            end
        end
=end
        self.referents = (self.referents + t2.referents).uniq
        
        # self.links = (self.links + t2.links).uniq
        
        # Correct any query that uses t2
        Rcpquery.all.each do |rq| 
            do_save = false
            rq.tags = rq.tags.each { |tag| ((do_save = true) && (tag.id = newid)) if tag.id == oldid }
            rq.save if do_save
        end
        
        t2.destroy
        return !self.errors.any?
    end
        
    # When a tag is asserted into the database, we do have minimal sanitary standards:
    #  no leading or trailing whitespace
    #  all internal whitespace is replaced by a single space character
    def self.tidyName(str)
        str.strip.gsub(/\s+/, ' ')
    end
    
    @@wordmap = {
        "chili" => "chile",
        "chilli" => "chile",
        "chille" => "chile",
        "chilly" => "chile",
        "chilie" => "chile",
        "chillie" => "chile",
        "chilis" => "chiles",
        "chillis" => "chiles",
        "chiles" => "chiles",
        "chilles" => "chiles",
        "chillys" => "chiles",
        "chilies" => "chiles",
        "chillies" => "chiles",
    }
    
    # Remove gratuitous characters, diacriticals, punctuation and capitalization for search purposes
    def self.normalizeName(str)
        str.strip.gsub(/[.,'‘’“”'"]+/, '').parameterize.split('-').collect{ |word| @@wordmap[word] || word }.join('-')
    end
    
    # Callback for tidying up the name and setting the normalized_name field and ensuring the tagtype
    # has a value
    def tagqa
        # Clean up the name by removing/collapsing whitespace
        self.name = Tag.tidyName self.name
        # ...and setting the normalized name
        self.normalized_name = Tag.normalizeName(self.name) unless self.normalized_name
        self.tagtype = 0 unless self.tagtype
        true
    end
    
   public 
   
   def typenum=(tt)
     # Need to be careful: the tag needs to agree in type with any expressions that include it
     tn = Tag.typenum tt
     return tn if (tn == self.tagtype) # Don't do anything if the type isn't changing
     return nil unless self.referents.all? { |ref| ref.drop self }
     self.tagtype = Tag.typenum(tt)
   end
   
   # Move the tag to a new type, possibly merging it with another tag of identical spelling
   def project(tt)
       newtypenum = Tag.typenum tt
       return self if self.tagtype == newtypenum # We're already in the target type!
       replacement = Tag.where(name: self.name, tagtype: newtypenum).first
       return nil unless (self.typenum = newtypenum)
       (replacement && replacement.absorb(self)) ? replacement : self
   end
   
   # Taking either a tag, a string or an id, make sure there's a corresponding tag
   #  of the given type that's available to the named user. NB: 't' may be a Tag, but
   #  not necessarily of the given type, or one available to the user.
   def self.assert_tag(t, opts = {} )
       # Convert tag type, if any, into internal form
       opts[:tagtype] = Tag.typenum(opts[:tagtype]) if opts[:tagtype]
       if t.class == Fixnum
           # Fetch an existing tag
           begin
               tag = Tag.find t
           rescue Exception => e
               return nil
           end
       elsif t.class == Tag
           tag = t 
       else
           opts[:assert] = true
           opts[:matchall] = true
           tag = Tag.strmatch(t, opts).first # strmatch will create a tag if none exists
           return nil if tag.nil?
       end
       # Now we've found/created a tag, we need to ensure it's the right type (if we care)
       puts "Found tag #{tag.name} (type #{tag.tagtype.to_s}) on key #{tag.id.to_s} using key #{t.to_s} and type #{opts[:tagtype].to_s}"
       unless tag.typematch opts[:tagtype]
           # Clone the tag for another type, but if it's a free tag, just change types
           tag = tag.dup if tag.tagtype != 0 # If free tag, just change type
           tag.tagtype = opts[:tagtype].kind_of?(Array) ? opts[:tagtype].first : opts[:tagtype]
           tag.isGlobal = opts[:userid].nil? # If userid not asserted, globalize it
           tag.save
       end
       # Ensure that the tag is available to the user (or globally, depending)
       # NB: Tag.strmatch does this, but not the other ways of getting here
       tag.admit_user opts[:userid]
       tag
   end
   
   # Expose this tag to the given user; if user is nil or super, make the tag global
   def admit_user(uid = nil)
       unless self.isGlobal
           if (uid.nil? || (uid == User.super_id))
               self.isGlobal = true
           elsif !self.owners.exists?(uid) # Reality check on the user id
               begin
                   user = User.find(uid)
                   self.owners << user 
               rescue
                   # Take no other action
               end 
           end
           self.save
       end
   end
   
   # Give this tag a primary meaning if it doesn't already have one or we're
   # forcing the issue
   def admit_meaning ref, force=false
       if !self.primary_meaning || force
           self.primary_meaning = ref
           self.save
       end 
   end
   
   # Look up a tag by name, userid and type, creating a new one if needed
   # RETURNS: an array of matching tags (possibly empty if assert is not true)
   # name: string to find
   # userid: user whose tags may be searched along with the global tags
   # tagtype: either a single value or an array, specifying key type(s) to search
   # assert: return a key of the given type matching the name, even if it has to be created anew
   # matchall: search only succeeds if it matches the whole string
   # untypedOK: add type 0 to search to look for untyped tags
   
   # If the :assert option is true, strmatch WILL return a tag on the given name, of the
   # given type, visible to the given user. This may not require making a new tag, but only opening 
   # an existing tag to the given user
  def self.strmatch(name, opts = {} )
    uid = opts[:userid]
    # Convert to internal form
    type = opts[:tagtype] && Tag.typenum(opts[:tagtype])
    assert = opts[:assert]
    name = name || ""  # nil matches anything
	# Case-insensitive lookup
	fuzzyname = Tag.normalizeName name
	if opts[:matchall] || assert
    	if type
        	tags = Tag.where normalized_name: fuzzyname, tagtype: type
        else # Specific collection of types
        	tags = Tag.where normalized_name: fuzzyname 
        end
    else # Substring match
    	if type
    	    if type.kind_of?(Array)
    	        # Sigh. Construct a query where the array of types is hardcoded
        	    tags = Tag.where "normalized_name like ? AND tagtype IN "+type.to_s.sub(/^\[(.*)\]$/, "(\\1)"), "%#{fuzzyname}%"
	        else
        	    tags = Tag.where "normalized_name like ? AND tagtype = ?", "%#{fuzzyname}%", type
    	    end
        else # Specific collection of types
        	tags = Tag.where "normalized_name like ? ", "%#{fuzzyname}%" 
        end
    end
    # We now have a list of tags which match the input, perhaps fuzzily.
    # If we don't need to assert the full string, we're done
    if assert
        # The tag set will be those which totally match the input. If there are none such, we need to create one
        unless tags.empty?
            # Since these match, we only need to make them visible to the user, if necessary
            tags.each { |tag| tag.admit_user uid } if uid && (uid != User.super_id)
        else
            # We are to create a tag on the given string (after cleanup), and make it visible to the given user
            name = Tag.tidyName name # Strip/collapse whitespace
            return [] if name.blank?
            tag = nil
            if type.nil? # No type specified
                tag = Tag.find_or_create_by_name name # It'll be a free tag, but if you don't care enough to specify...
            else
                if type.kind_of?(Array) # Look for the tag among the given types
                    type.find { |t| tag ||= Tag.find_by_name_and_tagtype(name, t) }
                    puts "Found tag #{tag.id} from array of types"
                else
                    tag = Tag.find_by_name_and_tagtype(name, type)
                end
                if tag.nil?
                    type = type.first if type.kind_of?(Array)
                    if tag = Tag.find_by_name_and_tagtype( name, 0 ) # Convert a free tag to the type, if avail.
                        tag.tagtype = type
                        tag.save
                    else
                        tag = Tag.create :name=>name, :tagtype=>type
                    end
                end
            end
            # If it's private, make it visible to this user
            tag.admit_user uid
            tags = [tag]
        end
    else
        # Restrict the found set to any asserted user
    	tags.keep_if { |tag| tag.isGlobal || tag.owners.exists?(uid) } if uid && (uid != User.super_id)
    end
    # Prioritize the list for initial substring matches
    if (!fuzzyname.blank?) && opts[:partition] && (tags.count > 1)
        firsttags = []
        lasttags = []
        tags.each { |tag| 
            if tag.normalized_name =~ /^#{fuzzyname}/
                firsttags << tag
            else
                lasttags << tag
            end
        }
        tags = firsttags + lasttags
    end
    tags
  end
  
  # Return a list of tags that "could be" a match for this one, as judged by losing the distinction
  # between singular and plural
  def aliases
      plural = self.name.pluralize
      singular = self.name.singularize
      list = []
      list = list + Tag.strmatch(singular, matchall: true, tagtype: self.tagtype) if singular != self.name
      list = list + Tag.strmatch(plural, matchall: true, tagtype: self.tagtype) if plural != self.name
      list
  end
   
   # Respond to a directive to move tags from one category to another
   def self.convertTypesByIndex(tagids, fromindex, toindex, globalize = false)
       # Iterate through the tags, keeping those we successfully change.
       # XXX We're assuming that these tags have no semantic information, 
       # i.e., they're orphans.
       fromType = self.index_to_type(fromindex)
       toType = self.index_to_type(toindex)
       tagids.keep_if do |id|
            if tag = self.find(id)
                tag.tagtype = toType; # XXX Should check for existing tag, folding them together if nec.
                tag.isGlobal = true if globalize
                tag.save
            end
       end
   end

    # Return a list of tags that are expressions of this tag's referent(s)
    def synonyms( opts = {} )
        self.referents.uniq.collect { |ref| ref.tags }.flatten.uniq 
    end
end

