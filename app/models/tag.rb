# encoding: UTF-8
class Tag < ActiveRecord::Base
    # require 'iconv'

    attr_accessible :name, :id, :tagtype, :typename, :isGlobal
    
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
    
    def self.tidyName(str)
        str.strip.gsub(/\s+/, ' ')
    end
    
    # Remove gratuitous characters, diacriticals, punctuation and capitalization for search purposes
    def self.normalizeName(str)
        str.strip.gsub(/[.,'‘’“”'"]+/, '').parameterize
    end
    
    def tagqa
        # Clean up the name by removing/collapsing whitespace
        self.name = Tag.tidyName self.name
        # ...and setting the normalized name
        self.normalized_name = Tag.normalizeName(self.name) unless self.normalized_name
        self.tagtype = 0 unless self.tagtype
        true
    end

    attr_reader :typename

   @@TypesToNames = ["free tag".to_sym, :Genre, :Role, :Process, :Food, :Unit, :Source, :Author, :Occasion, "Pantry Section".to_sym, "Store Section".to_sym, :Interest, :Tool ]
   @@NamesToTypes = {:Genre=>1, :Role=>2, :Process=>3, :Food=>4, :Unit=>5, :Source=>6, :Author=>7, :Occasion=>8 , "free tag".to_sym=>0, "Pantry Section".to_sym=>9, "Store Section".to_sym=>10, :Interest=>11, :Tool=>12}

   public 
   
   # Convert the tag type to external storage format, e.g. integer
   # We allow the type to be a string, a symbol, an integer index or an array of those types
   # A nil 'tt' is preserved on output (and an empty array returns nil) 
   def self.tagtype_inDB (tt)
       if tt.kind_of?(Array)
           tt.first && tt.collect { |type| self.tagtype_inDB type }
       else
           ((tt.kind_of? Fixnum) ? tt : @@NamesToTypes[tt.capitalize.to_sym]) if tt
       end
   end
   
   def self.typename(type)
       @@TypesToNames[type] || "free tag"
   end
   
   # Is my tagtype the same as the given type(s) (given as string, symbol, integer or array)
   def tagtype_is(tt)
       if tt.kind_of?(Array)
           tt.any? { |type| self.tagtype_is type }
       else
           Tag.tagtype_inDB(tt) == self.tagtype
       end
   end

   # Is my tagtype the same as the given type(s) (given as string, symbol or integer)
   def tagtype_matches(tt)
       tt.nil? || self.tagtype_is(tt) || (tt.kind_of?(Array) && (tt.empty? || tt.includes?(nil)))
   end

   def typename()
       self.tagtype.nil? ? "free tag" : @@TypesToNames[self.tagtype]
   end

   # Set the type of the tag, given in text
   def typename=(name)
       self.tagtype = self.tagtype_inDB(name) || 0
   end
   
   # Return an array listing the available types, where the index associates the type with the type name
   def self.typenames()
   	@@TypesToNames
   end
   
   def self.index_to_type(index)
       @@NamesToTypes[@@TypesToNames[index]]
   end
   
   # Taking either a tag, a string or an id, make sure there's a corresponding tag
   #  of the given type that's available to the named user. NB: 't' may be a Tag, but
   #  not necessarily of the given type, or one available to the user.
   def self.assert_tag(t, opts = {})
       debugger
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
           opts[:force] = true
           opts[:matchall] = true
           tag = Tag.strmatch(t, opts).first # strmatch will create a tag if none exists
           return nil if tag.nil?
       end
       # Now we've found/created a tag, we need to ensure it's the right type (if we care)
       puts "Found tag "+tag.name+" on key "+tag.id.to_s+" using key "+t.to_s
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
   
   # Expose this tag to the given user; if user is nil, make the tag global
   def admit_user(uid = nil)
       unless self.isGlobal
           if (uid.nil? || (uid == User.super_id))
               self.isGlobal = true
           elsif !self.users.exists?(uid)
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
   # uid: user whose tags may be searched along with the global tags
   # type: either a single value or an array, specifying key type(s) to search
   # assert: return a key of the given type matching the name, even if it has to be created anew
   # matchall: search only succeeds if it matches the whole string
   
   # If the :force option is asserted, strmatch WILL return a tag on the given name, of the
   # given type, visible to the given user. This may not require making a new tag, but only opening 
   # an existing tag to the given user
  def self.strmatch(name, opts = {} )
    debugger
    uid = opts[:userid]
    # Convert to internal form
    type = opts[:tagtype] && self.tagtype_inDB(opts[:tagtype])
    assert = opts[:force]
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
    if !assert
        # Restrict the found set to any asserted user
    	tags.keep_if { |tag| tag.isGlobal || tag.users.exists?(uid) } if uid && (uid != User.super_id)
    	return tags
    end
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

end

