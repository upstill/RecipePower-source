# encoding: UTF-8
class Tag < ActiveRecord::Base
  # require 'iconv'
  include Typeable
  # TODO: eliminate Channel and Collection types
  typeable(:tagtype,
           Untyped: ["Untyped", 0],
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
           CulinaryTerm: ["Culinary Term", 14],
           Question: ["Question", 15],
           List: ["List", 16],
           Epitaph: ["Epitaph", 17]
  )

  attr_accessible :name, :id, :tagtype, :isGlobal, :links, :referents, :users, :owners, :primary_meaning # , :recipes

  has_many :taggings, :dependent => :destroy
  has_many :dependent_lists, :class_name => "List", foreign_key: "name_tag_id"
  has_many :public_lists, -> { where(availability: 0) }, :class_name => "List", foreign_key: "name_tag_id"

  # expressions associate tags with the foods (roles, processes, etc.) they refer to
  # These are the "meanings" of a tag
  has_many :expressions, :dependent => :destroy
  has_many :referents, :through => :expressions

  # When a tag is used as the basis for a personal collection, destroying the tag destroys the collection
  has_many :private_subscriptions, :dependent => :destroy

  # The primary meaning is the default meaning of a tag
  belongs_to :primary_meaning, :class_name => "Referent", :foreign_key => "referent_id"

  # ownership of tags restrict visible tags
  has_many :tag_owners, :dependent => :destroy
  has_many :owners, :through => :tag_owners, :class_name => "User", :foreign_key => "user_id"

  validates_presence_of :name
  before_validation :tagqa

  # Delete this tag only if it's safe to do so
  def safe_destroy
    destroy if taggings.empty? && expressions.empty? && dependent_lists.empty?
  end

  # Pre-check to determine whether a tag can absorb another tag
  def can_absorb other
    other.normalized_name == self.normalized_name && ((other.tagtype==0) || (other.tagtype == self.tagtype))
  end

  def self.strscopes matcher
    [
      (block_given? ? yield() : self).where('"tags"."normalized_name" LIKE ?', matcher.downcase)
    ]
  end

  # Class method to define instance methods for the taggable entities: those of taggable_class
  # This is invoked by the Taggable module when it is included in a taggable
  def self.taggable taggable_class

    taggable_type = taggable_class.to_s.underscore
    ids_method_name = "#{taggable_type}_ids"

    define_method taggable_type.pluralize do |uid=nil|
      taggable_class.where id: self.method(ids_method_name).call(uid)
    end

    define_method ids_method_name do |uid=nil|
      scope = taggings.where entity_type: taggable_class
      scope = scope.where(:user_id => uid) if uid
      scope.map(&:entity_id).uniq
    end
  end

  # The Tag class defines taggable-entity association methods here. The Taggable class is consulted, and if it has
  # a :tag_with method (part of the Taggable module), then the methods get defined, otherwise we punt
  # NB All the requisite methods will have been defined IF the taggable's class has been defined (thank you, Taggable)
  # We're really only here to deal with the case where the Tag class (or a tag model) has been accessed before the
  # taggable class has been defined. Thus, the method_defined? call on the taggable class is enough to ensure the loading
  # of that class, and hence the defining of the access methods.
  def method_missing(meth, *args, &block)
    meth = meth.to_s
    # methstr = meth
    # methstr = ":#{methstr}" if meth.is_a? Symbol
    # puts "Tag method '#{methstr}' missing"
    begin
      taggable_class = ((match = meth.match(/(.+)_ids/)) ? match[1] : meth).singularize.camelize.constantize
      proof_method = :tag_with
      # puts "Extracted taggable_class '#{taggable_class}'"
      # puts "#{taggable_class} "+(taggable_class.method_defined?(proof_method) ? "has " : "does not have ")+"'#{proof_method}' method"
      if taggable_class.method_defined?(proof_method) && Tag.method_defined?(meth)
        self.method(meth).call *args, &block
      else
        # puts "Failed to define method '#{methstr}'"
        super
      end
    rescue Exception => e
      # puts "D'OH! Couldn't create association between Tag and #{taggable_class}"
      super
    end
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
    str.strip.gsub(/[.,'‘’“”'"]+/, '').parameterize.split('-').collect { |word| @@wordmap[word] || word }.join('-')
  end

  def clashing_tag
    Tag.where(name: name, tagtype: [tagtype, 0]).detect { |other| other.id != id }
  end

  # self can't be saved because some other tag already has its name/type combination. Find that tag and make self
  # disappear into it, UNLESS self already is typed and the other isn't, in which case the other disappears into
  # self. In any case, nuke the disappeared tag, and save and return the survivor
  # NB: this method functions like save but returns either the surviving tag (in case of success)
  #  or the original tag, with errors
  def disappear
    if target = clashing_tag
      ((target.tagtype == 0) && (tagtype != 0)) ? absorb(target) : target.absorb(self)
    else
      save
      self
    end
  end

  def absorb other
    # Normal procedure:
    TaggingServices.change_tag(other.id, self.id)
    ReferentServices.change_tag(other.id, self.id) # Change the canonical expression of any referent which uses us
    # Merge the general uses of other as an expression into those of the target
    self.referent_ids = (other.referent_ids+self.referent_ids).uniq
    self.primary_meaning ||= other.primary_meaning

    # Take on all owners of the absorbee unless one of them is global
    if self.isGlobal ||= other.isGlobal
      self.owners.clear
    else
      self.owner_ids = (other.owner_ids + self.owner_ids).uniq
    end
    if self.errors.any?
      # Failure: copy errors into the original record and return it
      self.errors.each { |k, v| other.errors[k] = v }
      other
    else
      Tag.transaction do
        other.destroy
        self.save
      end
      self
    end
  end

  # Callback for tidying up the name and setting the normalized_name field and ensuring the tagtype
  # has a value
  def tagqa
    # Clean up the name by removing/collapsing whitespace
    self.name = Tag.tidyName name
    # ...and setting the normalized name
    self.normalized_name = Tag.normalizeName name
    self.tagtype = 0 unless tagtype
    return true unless clashing_tag
    # Shouldn't be saved, because either 1) it will violate uniqueness, or 2) an existing untyped tag can be used
    self.errors[:key] = "Tag can't be saved because of possible redundancy"
    false
  end

  public

  # Return the tag's name with a marker of its type, to clear up ambiguities
  def typedname include_type=false, include_ref=false
    return name unless include_type && (typenum > 0)
    referent_str = (include_ref && referent_id && (" "+referent_id.to_s)) || ""
    %Q{#{name} [#{typename}#{referent_str}]}
  end

  def typenum=(tt)
    # Need to be careful: the tag needs to agree in type with any expressions that include it
    return typenum if typematch(tt) # Don't do anything if the type isn't changing
    return nil unless self.referents.all? { |ref| ref.drop self }
    self.tagtype = Tag.typenum(tt)
  end

  # Move the tag to a new type, possibly merging it with another tag of identical spelling
  def project(tt)
    return self if typematch(tt) # We're already in the target type!
    self.typenum = tt
    save
    clashing_tag ? disappear : self
  end

  # Taking either a tag, a string or an id, make sure there's a corresponding tag
  #  of the given type that's available to the named user. NB: 't' may be a Tag, but
  #  not necessarily of the given type, or one available to the user.
  def self.assert(t, opts = {})
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
  # fold: reduce the set of candidate tags using lexical and semantic equivalence classes

  # If the :assert option is true, strmatch WILL return a tag on the given name, of the
  # given type, visible to the given user. This may not require making a new tag, but only opening
  # an existing tag to the given user
  def self.strmatch(name, opts = {})
    uid = opts[:userid]
    # private_scope = uid ? Tag.find(TagOwner.where(user_id: uid).map(&:tag_id)) : nil
    # Convert to internal form
    type = opts[:tagtype] && Tag.typenum(opts[:tagtype]) # Restricted to types
    type_x = opts[:tagtype_x] && Tag.typenum(opts[:tagtype_x]) # Types excluded
    assert = opts[:assert]
    name = name || '' # nil matches anything
    do_fold = opts[:fold]
    # Case-insensitive lookup
    fuzzyname = Tag.normalizeName name
    if opts[:matchall] || assert
      if type
        tags = Tag.where normalized_name: fuzzyname, tagtype: type
      elsif type_x # Specific collection of types
        tags = Tag.where.not(tagtype: type_x).where normalized_name: fuzzyname
      else
        tags = Tag.where normalized_name: fuzzyname
      end
    else # Substring match
      if type
        typelist = (type.kind_of? Array) ? type.map(&:to_s).join(',') : type.to_s
        tags = Tag.where "normalized_name like ? AND tagtype IN (#{typelist})", "%#{fuzzyname}%"
      elsif type_x # Specific collection of types
        typelist = (type_x.kind_of? Array) ? type_x.map(&:to_s).join(',') : type_x.to_s
        tags = Tag.where.not("tagtype IN (#{typelist})").where "normalized_name like ?", "%#{fuzzyname}%"
      else
        tags = Tag.where "normalized_name like ? ", "%#{fuzzyname}%"
      end
    end
    tags = tags.limit(50)
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
          tag = Tag.find_or_create_by :name => name # It'll be a free tag, but if you don't care enough to specify...
        else
          if type.kind_of?(Array) # Look for the tag among the given types
            type.find { |t| tag ||= Tag.find_by_name_and_tagtype(name, t) }
            puts "Found tag #{tag.id} from array of types"
          else
            tag = Tag.find_by_name_and_tagtype(name, type)
          end
          if tag.nil?
            type = type.first if type.kind_of?(Array)
            if tag = Tag.find_by_name_and_tagtype(name, 0) # Convert a free tag to the type, if avail.
              tag.tagtype = type
              tag.save
            else
              tag = Tag.create :name => name, :tagtype => type
            end
          end
        end
        # If it's private, make it visible to this user
        tag.admit_user uid
        tags = [tag]
      end
    elsif uid && (uid != User.super_id)
      # Restrict the found set to any asserted user
      # user_tag_ids = TagOwner.where(user_id: uid).map(&:tag_id)
      # tags.keep_if { |tag| tag.isGlobal || user_tag_ids.include?(tag.id) }
      user_tag_id_list = TagOwner.where(user_id: uid).map(&:tag_id)
      unless user_tag_id_list.empty?
        user_tag_id_list = user_tag_id_list.collect { |id| id.to_s }.join ', '
        tags = tags.where %Q{"tags"."isGlobal" = 't' or "tags"."id" in (#{user_tag_id_list}) }
      else
        tags = tags.where isGlobal: true
      end
    else # No user specified => only global tags allowed
      tags = tags.where(isGlobal: true) unless uid == User.super_id
    end
    if do_fold
      # Fold the set of tags to reduce redundancy as follows:
      # -- at most one tag from the equivalence class of tags with the same normalized_name
      # -- at most one tag from the equivalence class of tags sharing a referent, with the referent's canonical expression preferred
      equivs = {}
      tags.each { |tag|
        accept = true
        if prior = equivs[tag.normalized_name]
          # Shootout between two lexically equivalent tags. Prefer the one whose match is earlier in the string,
          # then prefer the one with a case match
          case tag.name.index(/#{fuzzyname}/i) <=> prior.name.index(/#{fuzzyname}/i)
            when -1 # Old tag wins => Move on
              accept = false
            when 0
              accept = tag.name.match(fuzzyname)
          end
        end
        equivs[tag.normalized_name] = tag if accept

=begin Semantic folding didn't really work out. Necessary?
        tag.referent_ids.each { |rid|
          # Does the referent already have a representative in the equivs?
          equivs[tag.normalized_name] = tag unless (prior = equivs[rid]) &&
              (referent = Referent.find(rid)) &&
              (referent.tag_id == prior.id)
        }
=end
      }
      tags = equivs.values.uniq
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
  def synonyms(opts = {})
    self.referents.uniq.collect { |ref| ref.tags }.flatten.uniq
  end
end

