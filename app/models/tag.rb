# encoding: UTF-8
class Tag < ActiveRecord::Base
  # require 'iconv'
  include Typeable
  typeable(:tagtype,
           Untyped: ['Random', 0],
           Genre: ['Genre', 1],
           Dish: ['Dish', 2],
           Process: ['Process', 3],
           Ingredient: ['Ingredient', 4],
           Unit: ['Unit', 5],
           Source: ['Source', 6],
           Author: ['Author', 7],
           Occasion: ['Occasion', 8],
           PantrySection: ['Pantry Section', 9],
           StoreSection: ['Store Section', 10],
           Diet: ['Diet', 11],
           Tool: ['Tool', 12],
           Nutrient: ['Nutrient', 13],
           CulinaryTerm: ['Culinary Term', 14],
           Question: ['Question', 15],
           List: ['List', 16],
           Epitaph: ['Epitaph', 17],
           Course: ['Course', 18],
           Time: ['Time', 19],
           Hidden: ['Hidden', 20],
           Dual: ['Dual', 21]
  )

  attr_accessible :name, :id, :tagtype, :isGlobal, :links, :referents, :users, :owners, :primary_meaning # , :recipes

  has_many :taggings, :dependent => :destroy
  has_many :dependent_lists, :class_name => 'List', foreign_key: 'name_tag_id', :dependent => :restrict_with_error
  has_many :dependent_referents, :class_name => 'Referent', foreign_key: 'tag_id', :dependent => :nullify
  has_many :public_lists, -> { where(availability: 0) }, :class_name => 'List', foreign_key: 'name_tag_id'

  # expressions associate tags with the foods (roles, processes, etc.) they refer to
  # These are the 'meanings' of a tag
  has_many :expressions, :dependent => :destroy
  has_many :referents, :through => :expressions

  # When a tag is used as the basis for a personal collection, destroying the tag destroys the collection
  # has_many :private_subscriptions, :dependent => :destroy

  # The primary meaning is the default meaning of a tag
  belongs_to :primary_meaning, :class_name => 'Referent', :foreign_key => 'referent_id'

  # ownership of tags restrict visible tags
  has_many :tag_owners, :dependent => :destroy
  has_many :owners, :through => :tag_owners, :class_name => 'User', :foreign_key => 'user_id'

  scope :of_type, -> (type_or_types) {
    type_or_types.present? ? where(tagtype: type_or_types) : unscoped
  }

  scope :meaningless, -> {
    includes(:expressions).where(expressions: {id: nil})
  }

  # Scope for tags that can be used in the usual sense (to apply to entities), as opposed to other unique strings
  scope :taggables, -> { where(tagtype: ((0..14).to_a - [5]))}

  scope :untyped, -> { where(tagtype: 0) }

  # Scope for finding tags by name, either exact or embedded
  scope :by_string, -> (str, exact=false) {
    where("tags.normalized_name #{exact ? '=' : 'LIKE'} ?", "#{'%' unless exact}#{Tag.normalizeName str}#{'%' unless exact}")
  }

  # Scope for the collected synonyms of one or more tags
  scope :synonyms, -> (tag_id_or_ids) {
    joins(:referents).where( referents: { id: Referent.by_tag_id(tag_id_or_ids).pluck( :id) })
  }

  # Scope for finding tags which clash with this one
  scope :clashes, -> (tag) {
    where(name: tag.name, tagtype: [tag.tagtype, 0]).where.not(id: tag.id)
  }

  # Is there a tag that clashes with the (probably new) name and type of this one?
  def clashing_tag?
    Tag.clashes(self).exists?
  end

  # Identify a tag that clashes with the (probably new) name and type of this one (if any)
  def clashing_tag
    Tag.clashes(self).first
  end

  # Same, except accesses tags by name
  scope :synonyms_by_str, -> (str, exact=false) {
    joins(:referents).where(referents: { id: Referent.by_tag_name(str, exact).pluck(:id) } )
    # joins(:referents).where( referents: { id: Referent.by_tag_ids(tagids).pluck :id })
  }

  validates_presence_of :name
  before_validation :tagqa

  def meaning
    self.primary_meaning ||= (referents.first.becomes(Referent) if referents.first)
  end

  # Delete this tag only if it's safe to do so
  def safe_destroy
    destroy if taggings.empty? && expressions.empty? && dependent_lists.empty?
  end

  # Pre-check to determine whether a tag can absorb another tag
  def can_absorb other
    return true if (referent_ids == other.referent_ids)
    (other.normalized_name == self.normalized_name) && ((other.tagtype==0) || (other.tagtype == self.tagtype))
  end

  def self.strscopes matcher
    [
      (block_given? ? yield() : self).where('"tags"."normalized_name" LIKE ?', matcher.downcase)
    ]
  end

  # Check if a tag is already defined.
  # type_or_types may specify a single type or an array of types.
  # Options:
  # :strict matches the name, not the normalized_name
  # :visible_to specifies a user and returns false if it's not visible to that user
  def self.available? name, type_or_types=nil, options={}
    if type_or_types.is_a? Hash
      type_or_types, options = 0, type_or_types
    end
    constraints = { tagtype: (Tag.typenum(type_or_types) if type_or_types) }
    if options[:strict]
      constraints[:name] = name
    else
      constraints[:normalized_name] = normalizeName name
    end
    Tag.exists? constraints.compact
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
    taggable_class = ((match = meth.match(/(.+)_ids/)) ? match[1] : meth).singularize.camelize.constantize
    proof_method = :tag_with
    # puts "Extracted taggable_class '#{taggable_class}'"
    # puts "#{taggable_class} "+(taggable_class.method_defined?(proof_method) ? "has " : "does not have ")+"'#{proof_method}' method"
    if taggable_class.method_defined?(proof_method) && Tag.method_defined?(meth)
      begin
        self.method(meth).call *args, &block
      rescue Exception => e
        # puts "D'OH! Couldn't create association between Tag and #{taggable_class}"
        super
      end
    else
      super
    end
  end

  # When a tag is asserted into the database, we do have minimal sanitary standards:
  #  no leading or trailing whitespace
  #  no commas
  #  all internal whitespace is replaced by a single space character
  def self.tidyName(str)
    str.sub(/^[\s,]*/,'').sub(/[,\s]*$/, '').gsub(/\s+/, ' ')
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

  # Use this tag instead of 'other', i.e., absorb its taggings, referents, etc.
  # Either delete the other, or make it a synonym, according to 'delete'
  # Since either of the tags may disappear, return the survivor
  def absorb other, delete=true
    return other if other.id == id
    if (!meaning && other.meaning) || ((tagtype == 0) && (other.tagtype != 0)) # Make it easy for an unbound tag
      return other.absorb(self, delete)
    end
    # The other may clash with an existing tag of the target type,
    # So get either the other, or its equivalent in the appropriate type
    other = Tag.assert other, tagtype unless delete
    # ...which may indeed be the original
    return self if self == other
    begin
      # Normal procedure:
      Tag.transaction do
        # The important thing here is that we're making all requisite changes (to Taggings, Referents and Expressions)
        # directly in the database, to ensure consistency
        # Take on all owners of the absorbee unless one of them is global
        tag_owners.delete_all if self.isGlobal ||= other.isGlobal
        if delete
          # Redirect taggings, referents and expressions hither
          TagOwnerServices.change_tag other.id, id unless isGlobal # self.owner_ids = (other.owner_ids + owner_ids).uniq
          TaggingServices.change_tag other.id, id
          ReferentServices.change_tag other.id, id # Change the canonical expression of any referent which uses us
          ExpressionServices.change_tag other.id, id
        else
          TagOwnerServices.copy_tag other.id, id unless isGlobal # self.owner_ids = (other.owner_ids + owner_ids).uniq
          # Make this tag synonymous with the other => Ensure it has a matching set of referents and expressions
          # (taggings are unnecessary b/c the original is surviving)
          ExpressionServices.copy_tag other.id, id
        end
        # Merge the general uses of other as an expression into those of the target
        # TODO Need to move any lists named by the other
        if delete
          other.reload
          other.destroy
          other = self
        elsif other != self # No need to monkey with referents if the projection devolved on us
          # Make this tag synonymous with the other by ensuring it has the other's referents
          # Ensure that we have at least one referent
          Referent.express(self) unless primary_meaning || referents.first
          if !valid?
            # Failure: copy errors into the original record and return it
            errors.each { |k, v| other.errors[k] = v }
            raise other.full_messages
          end
          # Leave the other as a synonym
          other.update_attribute(:referent_id, referent_id) if referent_id
          ExpressionServices.copy_tag id, other.id
          other.reload
        end
        reload
      end
    rescue Exception => e
      # Errors should be present in the other record
    end
    other
  end

  # Callback for tidying up the name and setting the normalized_name field and ensuring the tagtype
  # has a value
  def tagqa
    # Clean up the name by removing/collapsing whitespace
    logger.info "Running 'tagqa'"
    self.name = Tag.tidyName name
    # ...and setting the normalized name
    self.normalized_name = Tag.normalizeName name
    self.tagtype = 0 unless tagtype
    if clashing_tag?
      # Shouldn't be saved, because either 1) it will violate uniqueness, or 2) an existing untyped tag can be used
      self.errors[:key] = "Tag can't be saved because of possible redundancy"
      false
    else
      true
    end
  end

  public

  # Return the tag's name with a marker of its type, to clear up ambiguities
  def typedname include_type=false, include_ref=false
    return name unless include_type
    type_label =
    if include_ref && meaning
      "#{meaning.model_name.human} ##{meaning.id}"
    else
      typename
    end
    %Q{#{name} [#{type_label}]}
  end

  def typenum=(tt)
    # Need to be careful: the tag needs to agree in type with any expressions that include it
    return typenum if typematch(tt) # Don't do anything if the type isn't changing
    return nil unless self.referents.all? { |ref| ref.drop self }
    self.tagtype = Tag.typenum(tt)
  end

  # Taking either a tag, a string or an id, make sure there's a corresponding tag
  #  of the given type that's available to the named user. If no type is asserted,
  #  any type will do.
  #
  #  NB: if a tag is presented, it's
  #  not necessarily of the given type, or available to the user. If a type conversion
  #  is required, the tag returned may differ from that provided.
  #
  #  One wrinkle: if there is a free tag (tagtype=0) that matches the given name (or the name
  #  of the given tag), it will be retyped to the requested type
  def self.assert tag_or_id_or_name, tagtype=nil, opts = {}
    tagtype, opts = nil, tagtype if tagtype.is_a? Hash
    # Convert tag type, if any, into internal form
    tagtype = Tag.typenum tagtype if tagtype
    extant_only = opts.delete :extant_only
    tag =
        case tag_or_id_or_name
          when Fixnum
            # Fetch an existing tag
            Tag.find_by id: tag_or_id_or_name
          when Tag
            tag_or_id_or_name
          else
            opts[:matchall] = true
            opts[:assert] = !extant_only
            if tagtype
              # Look for a matching tag of the correct type, then for an untyped match, then create one
              Tag.find_by(name: tag_or_id_or_name, tagtype: tagtype) ||
                  (Tag.find_by(name: tag_or_id_or_name, tagtype: 0) unless tagtype == 0) ||
                  Tag.strmatch(tag_or_id_or_name, opts.merge(tagtype: tagtype)).first
            else
              # Any type will do (but prefer an extant free tag)
              Tag.strmatch(tag_or_id_or_name, opts).first
            end
        end
    return nil if tag.nil?
    # Now we've found/created a tag, we need to ensure it's the right type
    if tagtype && (tag.tagtype != tagtype)
      # We have to be wary of a clash with an existing tag of the target type
      if t = Tag.find_by(name: tag.name, tagtype: tagtype)
        # Resolve the clash by using the existing one, absorbing the original if it's untyped
        t.absorb tag if tag.persisted? && (tag.tagtype == 0)
        tag = t
      else
        # Clone the tag for another type, but if it's a free tag, just change types
        tag = tag.dup if tag.persisted? && (tag.tagtype != 0)
        tag.tagtype = tagtype
      end
    end
    # Ensure that the tag is available to the user (or globally, depending)
    # NB: Tag.strmatch does this, but not the other ways of getting here
    tag.admit_user opts[:userid] if opts[:userid]
    tag.save! if tag.changed?
    tag
  end

  # Expose this tag to the given user; if user is nil or super, make the tag global
  def admit_user(uid = nil)
    unless isGlobal
      if (uid.nil? || (uid == User.super_id))
        self.isGlobal = true
      elsif !owners.exists?(uid) && (user = User.find_by id: uid) # Reality check on the user id
        self.owners << user
      end
    end
  end

  # Ensure that we no longer use this ref as a meaning
  def elide_meaning ref
    if ref
      self.primary_meaning = nil if primary_meaning == ref
      referents.delete ref
      expressions.each { |expr| expressions.delete(expr) if expr.referent == ref }
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
    tags =
    if opts[:matchall] || assert
      if type
        Tag.where normalized_name: fuzzyname, tagtype: type
      elsif type_x # Specific collection of types
        Tag.where.not(tagtype: type_x).where normalized_name: fuzzyname
      else
        Tag.where normalized_name: fuzzyname
      end
    else # Substring match
      if type
        typelist = [type].flatten.map(&:to_s).join(',')
        Tag.where "normalized_name like ? AND tagtype IN (#{typelist})", "%#{fuzzyname}%"
      elsif type_x # Specific collection of types
        typelist = [type_x].flatten.map(&:to_s).join(',')
        Tag.where.not("tagtype IN (#{typelist})").where "normalized_name like ?", "%#{fuzzyname}%"
      else
        Tag.where "normalized_name like ? ", "%#{fuzzyname}%"
      end
    end
    tags = tags.limit 75
    # We now have a list of tags which match the input, perhaps fuzzily.
    # If we don't need to assert the full string, we're done
    if assert
      # The tag set will be those which totally match the input. If there are none such, we need to create one
      if tags.present?
        # Since these match, we only need to make them visible to the user, if necessary
        tags.each { |tag| tag.admit_user uid } if uid && (uid != User.super_id)
      else
        # We are to create a tag on the given string (after cleanup), and make it visible to the given user
        name = Tag.tidyName name # Strip/collapse whitespace and commas
        return [] if name.blank?
        tag =
            if type
              # 'type' could be singular or an array
              types = [type].flatten
              types.find { |t| Tag.find_by_name_and_tagtype name, t } ||
                  if tag = Tag.find_by_name_and_tagtype(name, 0) # Convert a free tag to the type, if avail.
                    tag.update_attribute :tagtype, types.first
                    tag
                  else
                    Tag.create :name => name, :tagtype => types.first
                  end
            else # No type specified
              Tag.find_or_create_by :name => name, tagtype: 0 # It'll be a free tag, but if you don't care enough to specify...
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

