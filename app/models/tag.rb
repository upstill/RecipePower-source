# encoding: UTF-8
class Tag < ActiveRecord::Base
    # require 'iconv'

    attr_accessible :name, :id, :tagtype, :typename, :isGlobal, :meaning, :links, :recipes, :referents, :users
    
    # tagrefs associate tags with recipes
    has_many :tagrefs
    has_many :recipes, :through=>:tagrefs
    
    # expressions associate tags with the foods (roles, processes, etc.) they refer to
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

    # 'typename' is a virtual attribute for the string associated with the tag's type (tagtype attribute)

    attr_reader :typename
    def typename()
        self.tagtype.nil? ? "free tag" : @@TypesToNames[self.tagtype]
    end

    # Set the type of the tag, given in text
    def typename=(name)
        self.tagtype = self.tagtype_inDB(name) || 0
    end
   
   # This class method gives access to type names independent of any tag instances
   def self.typename(type)
       @@TypesToNames[type] || "free tag"
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

   # These class variables keep the mapping among tag types, type indices, and descriptive strings for the types
   @@TypesToSyms = [
       "free tag".to_sym, 
       :Genre, 
       :Role, 
       :Process, 
       :Food, 
       :Unit, 
       :Source, 
       :Author, 
       :Occasion, 
       :PantrySection, 
       :StoreSection, 
       :Interest, 
       :Tool, 
       :Nutrient, 
       :CulinaryTerm ]
       
# Translation from tag type to human-readable form
   @@TypesToNames = [
       "free tag", 
       "Genre", 
       "Role", 
       "Process", 
       "Food", 
       "Unit", 
       "Source", 
       "Author", 
       "Occasion", 
       "Pantry Section", 
       "Store Section", 
       "Interest", 
       "Tool", 
       "Nutrient", 
       "Culinary Term" ]

   @@NamesToTypes = {
       :Genre=>1, 
       :Role=>2, 
       :Process=>3, 
       :Food=>4, 
       :Unit=>5, 
       :Source=>6, 
       :Author=>7, 
       :Occasion=>8 , 
       "free tag".to_sym=>0, 
       :PantrySection=>9, 
       :StoreSection=>10, 
       :Interest=>11, 
       :Tool=>12,
       :Nutrient=>13,
       :Term=>14 }

   public 
   
   # For building into selection boxes, return a list of name/value pairs of all the tag types
   def self.tag_selections
       i = 0
       @@TypesToNames.collect { |name| [ name, i++ ]}
   end
   
   # Taking an index into the table of tag types, return the symbol for that type
   # (used to build a set of tabs, one for each tag type)
   # NB: returns nil for nil index
   def self.index_to_type(index)
       index && @@NamesToTypes[@@TypesToNames[index]]
   end
   
   # Convert the tag type to external storage format, e.g. integer
   # We allow the type to be a string, a symbol, an integer index or an array of those types
   # A nil 'tt' is preserved on output (and an empty array returns nil) 
   def self.tagtype_inDB (tt)
       if tt.kind_of? Fixnum 
           tt 
       elsif tt.kind_of? Symbol 
           @@NamesToTypes[tt]
       elsif tt.kind_of? String
           @@NamesToTypes[tt.split("\s").collect { |word| word.downcase.capitalize }.join('').to_sym]
       elsif tt.kind_of? Array
           tt.first && tt.collect { |type| self.tagtype_inDB type }
       end
   end
   
   # Is my tagtype the same as the given type(s) (given as string, symbol or integer)
   def tagtype_matches(tt)
       return true if tt.nil? # nil type matches any tag type
       if tt.kind_of?(Array)
           tt.any? { |type| self.tagtype_matches type }
       else
           Tag.tagtype_inDB(tt) == self.tagtype
       end
   end
   
   # Taking either a tag, a string or an id, make sure there's a corresponding tag
   #  of the given type that's available to the named user. NB: 't' may be a Tag, but
   #  not necessarily of the given type, or one available to the user.
   def self.assert_tag(t, opts = {} )
       # Convert tag type, if any, into internal form
       opts[:tagtype] = self.tagtype_inDB(opts[:tagtype]) if opts[:tagtype]
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
       unless tag.tagtype_matches opts[:tagtype]
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
           elsif !self.users.exists?(uid) # Reality check on the user id
               begin
                   user = User.find(uid)
                   self.users << user 
               rescue
                   # Take no other action
               end 
           end
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
    type = opts[:tagtype] && self.tagtype_inDB(opts[:tagtype])
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
    	tags.keep_if { |tag| tag.isGlobal || tag.users.exists?(uid) } if uid && (uid != User.super_id)
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
  
  # Merge a tag into another tag, to preserve uniqueness of tags within types
  def merge_into(id) 
      # Add any links associated with this tag to the target
      # If not global, add this tag's owners to target
      # Remove this tag from any referents that use it
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

