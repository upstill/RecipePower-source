class Tag < ActiveRecord::Base

    attr_accessible :name, :id, :tagtype, :typename, :isGlobal
    
    # tagrefs associate tags with recipes
    has_many :tagrefs
    has_many :recipes, :through=>:tagrefs
    
    # forms associate tags with the foods they (may) refer to
    has_many :expressions
    has_many :referents, :through=>:expressions
    
    # linkrefs give access to glossary entries, etc.
    has_many :link_refs
    has_many :links, :through=>:link_refs
    
    # ownership of tags restrict visible tags
    has_many :tag_owners
    has_many :users, :through=>:tag_owners
    
    validates_presence_of :name
    before_validation :tagqa
    
    def self.cleanupName(str)
        str.strip.gsub(/\s+/, ' ')
    end
    
    def tagqa
        # Clean up the name by removing/collapsing whitespace
        self.name = Tag.cleanupName self.name
        # ...and setting the normalized name
        self.normalized_name = self.name.parameterize unless self.normalized_name
        self.tagtype = 0 unless self.tagtype
        true
    end

    attr_reader :typename

   @@TypesToNames = ["free tag".to_sym, :Genre, :Role, :Process, :Food, :Unit, :Source, :Author, :Occasion, "Pantry Section".to_sym, "Store Section".to_sym, :Interest, :Tool ]
   @@NamesToTypes = {:Genre=>1, :Role=>2, :Process=>3, :Food=>4, :Unit=>5, :Source=>6, :Author=>7, :Occasion=>8 , "free tag".to_sym=>0, "Pantry Section".to_sym=>9, "Store Section".to_sym=>10, :Interest=>11, :Tool=>12}

   public 
   
   # Convert the tag type to external storage format, e.g. integer
   # We allow the type to be a string, a symbol or an integer
   def self.tagtype_inDB (tt)
       ((tt.kind_of? Fixnum) ? tt : @@NamesToTypes[tt.to_sym]) if tt 
   end
   
   # Does my tagtype match the given type (given as string, symbol or integer)
   def tagtype_is(tt)
       Tag.tagtype_inDB(tt) == self.tagtype
   end

   def typename()
       self.tagtype.nil? ? "free tag" : @@TypesToNames[self.tagtype]
   end

   # Set the type of the tag, given in text
   def typename=(name)
	self.tagtype = @@NamesToTypes[name.to_sym]
   end
   
   # Return an array listing the available types, where the index associates the type with the type name
   def self.typenames()
   	@@TypesToNames
   end
   
   def self.index_to_type(index)
       @@NamesToTypes[@@TypesToNames[index]]
   end
   
   # Using either a string or an id, make sure there's a corresponding tag
   #  and make it global if necessary
   def self.ensure_tag(t, type, global)
       if(t)
           if(t.class == Fixnum)
               # Check for existence of the tag
               tag = Tag.find t
               if global && !tag.isGlobal
                   tag.isGlobal = true
                   tag.save
               end
           else
               tag = Tag.strmatch(t, nil, type, global).first
               t = tag.id                
           end
       end
       t
   end
   
   # Look up a tag by name, userid and type, creating a new one if needed
   # RETURNS: an array of matching tags (possibly empty if assert is not true)
   # name: string to find
   # uid: user whose tags may be searched along with the global tags
   # type: either a single value or an array, specifying key type(s) to search
   # assert: return a key of the given type matching the name, even if it has to be created anew
   def self.strmatch(name, uid, type, assert)
    unrestricted = uid.nil? || uid==User.super_id # Let the super-user see all tags
    type = type || :any # nil type implies any type
    name = name || ""  # nil matches anything
    # type can be an array
    if(type.class==Array)
        type.map! { |t| self.tagtype_inDB t } # Convert type specifier to internal format
    else
        type = self.tagtype_inDB type if type != :any # Permits specifying type by symbol, string or integer type
    end
	if assert
	    # We are to create a tag on the given string (after cleanup), and make it visible to the given user
	    name = Tag.cleanupName name # Strip/collapse whitespace
	    return [] if name.blank?
	    if type == :any
	        tag = Tag.find_or_create_by_name name # It'll be a free tag, but hey...
        elsif ! (tag = Tag.find_by_name_and_tagtype name, type)
            if tag = Tag.find_by_name_and_tagtype( name, 0 ) # Convert a free tag to the type, if avail.
                tag.tagtype = (type.class==Array) ? type.first : type
                tag.save
            else
                tag = Tag.create :name=>name, :tagtype=>type
            end
        end
	    # If it's private, make it visible to this user
	    unless tag.isGlobal || (uid && tag.users.exists?(uid))
    	    if unrestricted # Super-user asserts it => Make it global
    	        tag.isGlobal = true
	        else
    	        tag.user_ids = tag.user_ids + [uid]
	        end
    	    tag.save
	    end
	    tags = [tag]
    else
    	# Case-insensitive lookup
    	fuzzyname = name.parameterize
    	if type == :any
        	tags = Tag.where "normalized_name like ? ", "%#{fuzzyname}%" 
	    else # Specific collection of types
        	tags = Tag.where "normalized_name like ? AND tagtype = ? ", "%#{fuzzyname}%", type
        end
    	tags.keep_if { |tag| tag.isGlobal || tag.users.exists?(uid) } unless unrestricted
	end
	tags
   end
   
   # Respond to a directive to move tags from one category to another
   def self.convertTypesByIndex(tagids, fromindex, toindex, globalize)
       # Iterate through the tags, keeping those we successfully change.
       # XXX We're assuming that these tags have no semantic information, 
       # i.e., they're orphans.
       fromType = self.index_to_type(fromindex)
       toType = self.index_to_type(toindex)
       tagids.keep_if do |id|
            if tag = self.find(id)
                tag.tagtype = toType;
                tag.isGlobal = true if globalize
                tag.save
            end
       end
   end

end

