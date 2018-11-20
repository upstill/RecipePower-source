class ReferentValidator < ActiveModel::Validator
  def validate(record)
    # Test that record has non-generic type
    unless record.type && record.type != 'Referent'
      record.errors[:base] << 'Referent can\'t have generic type'
      return false;
    end
    unless record.expression
      record.errors[:base] << 'A Referent must have at least one tag to express it.'
      return false
    end
    true
  end
end

class Referent < ApplicationRecord
  include Collectible
  include Taggable # Only so referents can appear on lists
  picable :picurl, :picture

  # Referents don't have a strict tree structure, just categories defined by an isa relationship.
  # This relationship is implemented by the ReferentRelation table, with parent_id and child_id keys
  has_many :child_relations, :foreign_key => 'parent_id', :dependent => :destroy, :class_name => 'ReferentRelation'
  has_many :children, -> { uniq }, :through => :child_relations, :source => :child

  has_many :parent_relations, :foreign_key => 'child_id', :dependent => :destroy, :class_name => 'ReferentRelation'
  has_many :parents, -> { uniq }, :through => :parent_relations, :source => :parent

  has_many :expressions, :dependent => :destroy
  has_many :tags, :through => :expressions
  accepts_nested_attributes_for :expressions, allow_destroy: true

  belongs_to :canonical_expression, :class_name => 'Tag', :foreign_key => 'tag_id'
  has_many :dependent_tags, :foreign_key => 'referent_id', :class_name => 'Tag', :dependent => :nullify

  has_many :referments, :dependent => :destroy, :inverse_of => :referent
  accepts_nested_attributes_for :referments

  before_destroy do
    # Must destroy any referments that refer to us as :referee
    Referment.where(referee_id: self.id, referee_type: self.class.to_s).destroy_all
  end
  # What can we get to through the referments? Each class that includes the Referrable module should be in this list
  @@referment_associations = %w{
      PageRef
      ImageReference
      Recipe
      Product
      Referent
      SourceReferent
      InterestReferent
      GenreReferent
      RoleReferent
      DishReferent
      CourseReferent
      ProcessReferent
      IngredientReferent
      AuthorReferent
      OccasionReferent
      PantrySectionReferent
      StoreSectionReferent
      DietReferent
      ToolReferent
      NutrientReferent
      CulinaryTermReferent
      QuestionReferent
      ListReferent
      EpitaphReferent
      CourseReferent
      TimeReferent
  }
  @@referment_associations.each { |assoc|
    has_many assoc.underscore.pluralize.to_sym, :through => :referments, :source => :referee, :source_type => assoc
  }
  has_many :relateds, :through => :referments, :source => :referee, :source_type => 'Referent'

  has_many :page_refs, :through => :referments, :source => :referee, :source_type => 'PageRef', inverse_of: :referents
  accepts_nested_attributes_for :page_refs

  # Each Product may have numerous Offerings
  has_many :offerings, :through => :products
  # has_many :referents, :through => :referments, :source => :referee, :source_type => 'Referent'

=begin
    def self.referrable klass
      has_many klass.to_s.pluralize.underscore, :through => :referments, :source => :referee, :source_type => klass
    end

  # attr_accessible :tag, :type, :description, :isCountable, :dependent,
                  :canonical_expression, :expressions_attributes, :add_expression, :tag_id,
                  :page_refs_attributes,
                  :parents, :children, :relateds,
                  :parent_tag_tokens, :child_tag_tokens, :related_tag_tokens,
                  :typeindex
=end

  attr_accessor :dependent

  # validates_associated :parents
  # validates_associated :children
  validates_with ReferentValidator

  after_save do |ref|
    # If the canonical expression has been removed from the tag set, pick a new one
    unless ref.canonical_expression && ref.tags.where(id: ref.canonical_expression.id).exists?
      newcon = ref.tags.first
      ref.canonical_expression = newcon
      ref.update_attribute :tag_id, (newcon.id if newcon) if ref.tag_id
    end
  end
  after_save :ensure_tagtypes

  after_create do |ref|
    # Want to ensure the tag appears among our expressions, but
    # that can only be done after the ref has been saved (so it can be attached to the tag)
    ref.express ref.canonical_expression
  end

  # Scopes for the referents of the given tag(s)
  scope :by_tag_id, -> (tagid_or_ids) { joins(:tags).where(tags: {id: tagid_or_ids}) }

  scope :by_tag_name, -> (str, exact=false) {
    # joins(:tags).where("tags.normalized_name #{exact ? '=' : 'LIKE'} ?", "#{'%' unless exact}#{Tag.normalizeName str}#{'%' unless exact}")
    joins(:tags).merge(Tag.by_string str, exact)
  }

  def self.strscopes matcher
    [
        (block_given? ? yield() : self).joins(:tags).where('"tags"."name" ILIKE ?', matcher)
    ]
  end

  def affiliates
    @affiliates ||=
        referments.pluck(:referee_type, :referee_id).inject({}) { |memo, rfm|
          classname = rfm.first.sub(/.*Referent/, 'Referent')
          memo[classname] ||= []
          memo[classname] << rfm.last
          memo
        }.collect { |classname, ids|
          scope =
              case classname
                when 'Referent'
                  Referent.includes :canonical_expression
                when 'Recipe'
                  Recipe.includes :page_ref
                else
                  classname.constantize
              end
          scope.where(id: ids).to_a
        }.flatten
  end

  def absorb other, nuke_it=true
    return false if type != other.type
    return true if other.id == id
    puts "Merging '"+name+"' (#{children.count} children) with '"+other.name+"' (#{other.children.count} children):"
    other.children.each { |child| children << child unless (child_ids.include? child.id) }
    other.parents.each { |parent| parents << parent unless (parent_ids.include? parent.id) }
    other.expressions.each { |expr| self.express expr.tag }
    # Whatever entities can be reached through referments, copy those
    @@referment_associations.each { |assoc|
      collection_method = assoc.to_s.underscore.pluralize.to_sym
      collection = self.method(collection_method).call
      ids = collection.pluck :id
      other.method(collection_method).call.each { |entity| collection << entity unless (ids.include? entity.id) }
    }
    self.description = other.description if description.blank?
    self.save
    other.destroy if nuke_it
    self.reload
  end

  # The associate is the model associated with any particular class of referent, if any
  # By default, referents have no associate; currently, Sources have one
  def associate
    nil
  end

  # Dump the contents of the database to stdout
  def self.dump tagtype=4
    Referent.all.collect { |ref| ref.parents.empty? && (ref.typenum==tagtype) && ref }.each { |tl| tl.dump if tl }
  end

  # Dump a specified referent with the given indent
  def dump indent = "", path = []
    if path.include? self.id
      puts "#{indent}!!Loop back to #{self.id.to_s}: #{self.name}"
    else
      puts "#{indent}Referent #{self.id.to_s}: #{self.name}"
      indent = indent + "    "
      self.tags.each do |tag|
        puts "#{indent}Tag #{tag.id.to_s}: #{tag.name}"
        tag.links.each { |link| puts "#{indent}    Link #{link.id.to_s}: #{link.uri}" }
      end
      self.children.each { |child| child.dump(indent, path+[self.id]) }
    end
  end

  # After saving, check that all tags are of our type
  def ensure_tagtypes
    mytype = self.typenum
    self.tags.each do |tag|
      # Ensure that all associated tags have the right type, are global, and have a meaning
      unless tag.tagtype == mytype && tag.is_global
        if tag.tagtype != mytype && (tag.tagtype > 0) # ERROR!! Can't convert tag from another type
          errors.add(:tags, "#{tag.name} is a '#{tag.typename}', not '#{Tag.typename(mytype)}'")
        else
          tag.tagtype = mytype
          tag.is_global = true
          tag.save
        end
      end
    end
  end

  # This is a virtual attribute for the benefit of the referent editor, which has
  # a tokenInput field for adding expressions. In reality, there should never be any text
  # in this field when the form is submitted. If there is, we just ignore it
  def add_expression
  end

  def add_expression=(tag)
  end

  # Virtual attributes for parent, child and related referents. These are represented by tags,
  # so getting and setting involves token lookup. Since parents and children are both
  # just sets of referents, these v.a.s go through a single pair of methods
  def parent_tag_tokens
    parent_tags.map(&:attributes).to_json
  end

  def parent_tags
    tags_from_referents self.parents
  end

  def parent_tag_tokens=(tokenlist)
    # After collecting tags, scan list to eliminate references to self
    tokenlist = tokenlist.split(',')
    self.parent_ids = tag_tokens_to_referents(tokenlist).
        delete_if { |rel| (rel.id == self.id) && errors.add(:parents, 'Can\'t be its own parent.') }.
        uniq.
        map(&:id)
  end

  def child_tag_tokens
    child_tags.map(&:attributes).to_json
  end

  def child_tags
    tags_from_referents self.children
  end

  def child_tag_tokens=(tokenlist)
    # After collecting tags, scan list to eliminate references to self
    tokenlist = tokenlist.split(',')
    self.children = tag_tokens_to_referents(tokenlist).delete_if { |rel| (rel.id == self.id) && errors.add(:children, "Can't be its own child.") }.uniq
  end

  def related_tag_tokens
    related_tags.map(&:attributes).to_json
  end

  def related_tags
    tags_from_referents self.relateds
  end

  def related_tag_tokens=(tokenlist)
    # After collecting tags, scan list to eliminate references to self
    tokenlist = tokenlist.split(',')
    self.relateds = tag_tokens_to_referents(tokenlist).delete_if { |rel| (rel.id == self.id) && errors.add(:related, "Can't suggest itself.") }.uniq
  end

  # Convert a list of referents into the tags that reference them.
  def tags_from_referents(referents)
    referents.map &:expression
  end

  # Convert a list of tag tokens into the referents to which they refer
  def tag_tokens_to_referents(tokens, use_existing=true)
    refs = tokens.inject([]) { |set, token|
      # We either match the referent to token or create a new one
      token.strip!
      token = token.to_i unless token.sub!(/^\'(.*)\'$/, '\1')
      ref = Referent.express token, self.typenum
      # Ignore failed referents and eliminate redundancies
      set << ref unless !ref || set.find { |collected| collected.id == ref.id }
      set
    }
    puts 'Tokens converted to referents: '+refs.inspect
    refs
  end

  def self.referent_class_for_tagtype(typenum)
    (((typenum > 0) ? Tag.typesym(typenum).to_s : '')+'Referent')
  end

  # Class method to create a referent of a given type under the given tag,
  # or to find an existing one.
  # Parameters:
  # -- 'tag_or_id_or_string' may be an extant tag, or the id of a tag, or a string
  # -- 'tagtype' may be a symbol, an integer or a string, according to the typing of Tags
  #     (Since you can't #express a free tag (type 0) 'tagtype' must not be :Free if creating a tag)
  def self.express (tag_or_id_or_string, tagtype = nil, args = {})
    if tagtype.is_a? Hash
      tagtype, args = nil, tagtype
    end
    typenum =
        if tag_or_id_or_string.is_a?(Tag) && !tagtype
          tag_or_id_or_string.tagtype
        else
          Tag.typenum tagtype
        end
    # The tagtype must be something other than 0 unless the tag already has such a type
    if typenum != 0
      Referent.transaction do
        # Creating it if need be, and/or making it global
        if tag = Tag.assert(tag_or_id_or_string, typenum)
          # We may not immediately have a referent for this tag
          #...but there may already be one as a plural or a singular
          ref = (tag.meaning ||
              tag.aliases.map(&:meaning).find(&:'present?')) unless args.delete(:force)
          # Tag doesn't have an existing referent (or we're forcing), so need to make one
          ref ||= Referent.referent_class_for_tagtype(tag.tagtype).constantize.create(canonical_expression: tag)
          ref.express tag, args
          ref
        end
      end
    end
  end

  # Add a tag to the expressions of this referent, returning the tag id
  def express(tag_or_id_or_name, args = {})
    if !persisted?
      errors.add :tags, "can't be used as expressions until referent is saved"
      return nil
    end
    # We assert the tag in case it's
    # 1) specified by string or id, rather than a tag object
    # 2) of a different type, or
    # 3) not already global
    if tag = Tag.assert(tag_or_id_or_name, self.typenum) # Ensure that there's a tag of OUR type

      # Promote the tag to the canonical expression on this referent if needed
      if (args[:form] == :generic) && (canonical_expression != tag)
        self.canonical_expression = tag
        update_attribute :tag_id, tag.id
      end

      # Find or create an expression of this referent on this tag. If locale
      # or form aren't specified, match any expression
      args[:form] ||= ::Expression.formnum :generic
      scrubbed_args = Expression.scrub_args(args).merge tag: tag, referent: self.becomes(Referent)
      unless expressions.exists?(scrubbed_args)
        tag.save if tag.changed?
        expr = tag.expressions.create(scrubbed_args)
        self.expressions << expr
        tag.reload # To ensure the tag's referents are current
      end
    else
      self.errors.add :tags, "won't take bogus tag as expression"
    end
    tag
  end

  # alias_method :orig_canonical_expression=, :canonical_expression=
  def canonical_expression= tag_or_string
    tag = tag_or_string.is_a?(String) ? Tag.assert(tag_or_string, typenum) : tag_or_string
    if tag && (tag.tagtype == typenum)
      super tag
      update_attribute(:tag_id, tag.id) if tag_id_changed? && tag.id # Save for later
      express tag if persisted? # Ensure the tag is listed among the expressions
      true
    elsif tag
      # It is an error to assign a tag to a referent of the wrong type
      errors.add :canonical_expression, "#{tag.typename} tag can't express #{typename} referent"
      false
    else
      # There's not even a bloody tag!
      errors.add :canonical_expression, "#{tag_or_string} can't express #{typename} referent"
    end
  end

  # Return a list of all tags that are related to the one provided. This means:
  # ...all the synonyms (if required) and
  # ...all the parents (if required) of
  # ...all the children (if required) of
  # ...all the referents of this tag
  # TODO: currently unused; should be optimized and employed in searching by tags
  def self.related tag, doSynonyms = false, doParents = false, doChildren = false
    unique_referents = tag.referents.collect { |ref|
      [(ref.parents if doParents), (ref.children if doChildren)]
    }.flatten.compact.uniq - tag.referents
    tag_ids = unique_referents.collect { |ref| ref.tag_id }
    tag_ids = tag_ids + tag.referents.collect { |ref| ref.tag_id } if doSynonyms
    tag_ids.uniq.delete_if { |id| id == tag.id }.collect { |id| Tag.find id }
  end

  def self.type_to_class type
    (type && (type > 0) && Tag.typesym(type) && (Tag.typesym(type).to_s+"Referent").constantize) || Referent
  end

  def typesym
    self.type && self.type.sub(/Referent/, '').to_sym
  end

  def typename
    Tag.typename self.typesym
  end

  def typenum
    Tag.typenum self.typesym
  end

  def self.show_tree(key = nil, level = 0)
    children = []
    if key
      ref = Referent.find key
      puts ("    "*level)+"#{ref.id.to_s}: #{ref.name} (#{ref.tag_id})"
      children = ref.children
      level = level+1
    else
      children = self.roots
    end
    children.each { |child| self.show_tree child.id, level }
  end

  def self.create(*params)
    parentid = 0
    if params.first
      parentid = params.first[:parent_id] ? params.first[:parent_id].to_i : 0
      # params.first.delete :parent_id # closure_tree will add the parent
    end

    if (result = super) && (parentid > 0)
      # We give the new node a parent
      if (parent = Referent.find parentid)
        parent.add_child result
        result.save
        parent.save
      end
    end
    result
  end

  # Return an array of all paths leading to this leaf node
  def paths_to inText = true, collected = []
    paths = []
    (self.parent_ids - collected).each do |parent_id|
      parent = Referent.find parent_id
      paths = paths + parent.paths_to(false, collected + [parent.id])
    end
    paths = paths.empty? ? [[self]] : paths.collect { |path| path << self }
    return paths unless inText
    paths.collect { |path| path.collect { |node| node.name }.join('/') }
  end

  def update_attributes(*params)
    actuals = params.first

    # We take care of the page_refs list here
    if pras = actuals['page_refs_attributes']
      # Ensure that we have Referments for each PageRef that hasn't been deleted
      pras.each { |id, values|
        prid = values['id'].to_i
        if values['_destroy'] == 'false'
          # Keep it/add it
          pr =
          if page_refs.exists? id: prid
            page_refs.find prid
          else
            page_refs << (pr = PageRef.find prid)
            pr
          end
          # Make sure the type matches
          if pr.kind != values['kind']
            pr.update_attribute :kind, values['kind']
          end
        elsif page_refs.exists?(id: prid)
          # Nuke it
          page_refs.delete page_refs.where(id: prid).first
        end
      }
      actuals.delete 'page_refs_attributes'
    end

    # If the parent id is changing, we need to make sure the tree stays sound
    if actuals[:parent_id]
      # We're specifying a new parent:
      #   -- If mode is "over", the parent_id gives our new parent
      #   -- If mode is "before" or "after", we attach to that node's parent
      parent = self.class.find actuals[:parent_id].to_i
      parent = parent.parent if actuals[:mode] != 'over'
      if parent
        if parent.id != self.parent_id # Avoiding redundant move
          parent.add_child self
          parent.save
          self.save
        end
      else
        # No parent: this node will become a root
        if self.parent_id && self.parent_id > 0 # Not already a root node...
          # ...make it one
        end
      end
      params.first.delete :parent_id
    end
    params.first.delete :mode
    # Run the regular updater if there are any parameters left
    if params.first.empty?
      true
    else
      super
    end
  end

  # Remove uses of this tag by this referent
  # A tagid may be passed
  def drop tag_or_id
    id_to_drop = (tag_or_id.is_a? Tag) ? tag_or_id.id : tag_or_id
    if !tag_id || (tag_id == id_to_drop)
      # Need to find another tag to use for canonical string; reuse the dropped tag iff it's valid
      self.tag_id = (tag_ids - [id_to_drop]).first || (id_to_drop if tags.map(&:id).include?(id_to_drop))
    end
    expr_to_nuke = expressions.find_by(tag_id: id_to_drop) unless self.tag_id == id_to_drop
    self.expressions.destroy expr_to_nuke if expr_to_nuke
    save if changed?
  end

  # Return the tag expressing this referent according to the given form and locale, if any
  def expression args = {}
    args = ::Expression.scrub_args args
    if (args.size > 0) && (expr = expressions.find_by args)
      return expr.tag
    elsif !canonical_expression
      expr = expressions.find_by(Expression.scrub_args :form => :generic) || expressions.first
      self.canonical_expression = expr.tag if expr
    end
    canonical_expression
  end

  # Return the name of the referent
  def normalized_name args = {}
    (tag = self.expression args) ? tag.normalized_name : "**no tag**"
  end

  # Return the name of the referent
  def name args = {}
    (tag = self.expression args) ? tag.name : "**no tag**"
  end

  # Return the name, appended with all associated forms
  def longname
    result = self.name
    aliases = self.tags.uniq.select { |tag| tag.id != self.tag_id }.map { |tag| tag.name }.join(", ")
    result << "(#{aliases})" unless aliases.blank?
    result
  end

  # Assert a parent-child relationship in the tree, taking care not to introduce cycles
  # If 'move' is true, we're unplugging before moving within the tree, otherwise copying the ref into a new place.
  def make_parent_of child_ref, move=true
    if self == child_ref # Synonyms of the same referent => split off a new referent to establish the child
      errors.add :children, "can't make them parent and child: they're the same!"
      return
    end

    if path = ReferentServices.new(self).ancestor_path_to(child_ref)
      report = "Referent ##{child_ref.id} (#{child_ref.name}) can't be adopted as a child of ##{id} (#{name}): it's an ancestor!\n"
      ellipsis = 'Path:'
      path.each { |ref|
        report << "  #{ellipsis} Referent ##{ref.id} (#{ref.name})\n"
        ellipsis = '...has child'
      }
      errors.add :ancestor, report
      return
    end
    unless children.include? child_ref
      if move
        child_ref.parents = [self]
      else
        child_ref.parents << self
      end
      children << child_ref
      save
      child_ref.save
    end
  end

  # Declare a relationship between two referents
  def suggests target_ref
    target_ref.save unless target_ref.id
    # author_referents << target_ref unless author_referents.include?(target_ref)
    referments.create(referee: target_ref) unless suggests?(target_ref)
  end

  def suggests? target_ref
    referments.exists? referee: target_ref
  end

  # Can the referent be destroyed, ie., is it empty of all connections?
  def detached?
    expressions.empty? && referments.empty? && parents.empty? && children.empty?
  end
end

# Subclases for different types of referents
if defined?(SourceReferent)
  x=2 # raise "SourceReferent already defined!"
else

  class SourceReferent < Referent
    has_one :site, foreign_key: 'referent_id'

    # attr_accessible :site

    def associate
      self.site
    end

    def detached?
      super && !site
    end

    def affiliates
      (super + [site]).compact
    end

  end


  class InterestReferent < Referent
  end

  class GenreReferent < Referent
  end

  class RoleReferent < Referent
  end

  class DishReferent < Referent
  end

  class CourseReferent < Referent
  end

  class ProcessReferent < Referent
  end

  class IngredientReferent < Referent
  end

  class UnitReferent < Referent
  end

  class AuthorReferent < Referent
  end

  class OccasionReferent < Referent
  end

  class PantrySectionReferent < Referent
  end

  class StoreSectionReferent < Referent
  end

  class DietReferent < Referent
  end

  class ToolReferent < Referent
  end

  class NutrientReferent < Referent
  end

  class CulinaryTermReferent < Referent
  end

  class QuestionReferent < Referent
  end

  class ListReferent < Referent
  end

  class EpitaphReferent < Referent
  end

  class CourseReferent < Referent
  end

  class TimeReferent < Referent
  end
end
