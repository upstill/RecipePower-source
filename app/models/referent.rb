
class ReferentValidator < ActiveModel::Validator
  def validate(record)
    # Test that record has non-generic type
    unless record.type && record.type != 'Referent'
      record.errors[:base] << 'Referent can\'t have generic type'
      return false;
    end
    if record.tags.empty? && !record.canonical_expression
      record.errors[:base] << 'A Referent must have at least one tag to express it.'
      return false
    end
    true
  end
end

class Referent < ActiveRecord::Base
  include Picable

  # picable :picurl, :picture
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

  has_many :referments, :dependent => :destroy, :inverse_of => :referent
  # What can we get to through the referments? Each class that includes the Referrable module should be in this list
  @@referment_associations = %w{
      PageRef
      Reference
      Recipe
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
  has_many :image_refs, -> { where type: 'ImageReference' }, :through => :referments, :source => :referee, :source_type => 'Reference'
  has_many :definition_refs, -> { where type: 'DefinitionReference' }, :through => :referments, :source => :referee, :source_type => 'Reference'

=begin
    def self.referrable klass
      has_many klass.to_s.pluralize.underscore, :through => :referments, :source => :referee, :source_type => klass
    end
=end

  attr_accessible :tag, :type, :description, :isCountable, :dependent,
                  :expressions_attributes, :add_expression, :tag_id,
                  :parents, :children, :parent_tokens, :child_tokens, :typeindex

  attr_accessor :dependent

  # validates_associated :parents
  # validates_associated :children
  validates_with ReferentValidator

  before_destroy :fix_references

  # before_save :ensure_expression
  after_save :ensure_tagtypes

  def self.strscopes matcher
    [
        (block_given? ? yield() : self).joins(:tags).where('"tags"."name" ILIKE ?', matcher)
    ]
  end

  def absorb other, nuke_it=true
    return false if type != other.type
    return true if other.id == id
    puts "Merging '"+name+"' (#{children.count} children) with '"+other.name+"' (#{other.children.count} children):"
    other.children.each { |child| children << child }
    other.parents.each { |parent| parents << parent }
    other.expressions.each { |expr| self.express expr.tag }
    # Whatever entities can be reached through referments, copy those
    @@referment_associations.each { |assoc|
      collection_method = assoc.to_s.underscore.pluralize.to_sym
      collection = self.method(collection_method).call
      other.method(collection_method).call.each { |entity| collection << entity }
    }
    self.description = other.description if description.blank?
    self.save
    other.destroy if nuke_it
    self.reload
  end

  # Callback before destroying this referent, to fix any tags that use it as primary meaning
  def fix_references
    tags.each do |tag|
      if tag.primary_meaning == self
        # Choose a new primary meaning
        tag.referents.each do |referent|
          if referent != self
            tag.primary_meaning = referent
            tag.save
            return
          end
        end
        tag.primary_meaning = nil
        tag.save
      end
    end
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
      unless tag.tagtype == mytype && tag.isGlobal
        if tag.tagtype != mytype && (tag.tagtype > 0) # ERROR!! Can't convert tag from another type
          errors.add(:tags, "#{tag.name} is a '#{tag.typename}', not '#{Tag.typename(mytype)}'")
        else
          tag.tagtype = mytype
          tag.primary_meaning = self unless tag.primary_meaning # Give tag this meaning if there's no other
          tag.isGlobal = true
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

  # Virtual attributes for parent and child referents. These are represented by tags,
  # so getting and setting involves token lookup. Since parents and children are both
  # just sets of referents, these v.a.s go through a single pair of methods
  def parent_tokens
    parent_tags.map(&:attributes).to_json
  end

  def parent_tags
    tags_from_referents self.parents
  end

  def parent_tokens=(tokenlist)
    # After collecting tags, scan list to eliminate references to self
    tokenlist = tokenlist.split(',')
    self.parents = tag_tokens_to_referents(tokenlist).delete_if { |rel| (rel.id == self.id) && errors.add(:parents, 'Can\'t be its own parent.') }.uniq
  end

  def child_tokens
    child_tags.map(&:attributes).to_json
  end

  def child_tags
    tags_from_referents self.children
  end

  def child_tokens=(tokenlist)
    # After collecting tags, scan list to eliminate references to self
    tokenlist = tokenlist.split(',')
    self.children = tag_tokens_to_referents(tokenlist).delete_if { |rel| (rel.id == self.id) && errors.add(:children, "Can't be its own child.") }.uniq
  end

  # Convert a list of referents into the tags that reference them.
  def tags_from_referents(referents)
    referents.collect { |ref| ref.canonical_expression }
  end

  # Convert a list of tag tokens into the referents to which they refer
  def tag_tokens_to_referents(tokens, use_existing=true)
    refs = tokens.collect { |token|
      # We either match the referent to token or create a new one
      token.strip!
      token = token.to_i unless token.sub!(/^\'(.*)\'$/, '\1')
      Referent.express token, self.typenum
    }.compact # Blow off failed referents
    puts 'Tokens converted to referents: '+refs.inspect
    refs
  end

  def self.referent_class_for_tagtype(typenum)
    (((typenum > 0) ? Tag.typesym(typenum).to_s : '')+'Referent')
  end

  # Class method to create a referent of a given type under the given tag,
  # or to find an existing one.
  # WARNING: while some effort is made to find an existing referent and use that,
  #  this procedure lends itself to redundancy in the dictionary
  def self.express (tag, tagtype = nil, args = {})
    if tag.class == Tag # Creating it if need be, and/or making it global
      tagtype = tag.tagtype
    else
      tag = Tag.assert(tag, tagtype: tagtype)
    end
    ref = tag.primary_meaning ||
        tag.referents.first ||
        # We don't immediately have a referent for this tag
        #...but there may already be one as a plural or a singular
        tag.aliases.collect { |tag| tag.primary_meaning || tag.referents.first }.compact.first ||
        # Tag doesn't have an existing referent, so need to make one
        Referent.referent_class_for_tagtype(tag.tagtype).constantize.create(tag_id: tag.id)
    if ref.id # Successfully created
      ref.express tag, args
      ref
    end
  end

  # Add a tag to the expressions of this referent, returning the tag id
  def express(tag, args = {})
    # We assert the tag in case it's
    # 1) specified by string or id, rather than a tag object
    # 2) of a different type, or
    # 3) not already global
    name = tag.is_a?(String) ? tag : tag.name
    tag = Tag.assert tag, tagtype: self.typenum
    if tag.name != name
      tag.name = name # We may be setting the name to something that matches an existing tag
      tag.save
    end

    # Promote the tag to the canonical expression on this referent if needed
    if (args[:form] == :generic) || !self.canonical_expression
      self.canonical_expression = tag
      self.save
    end

    # Find or create an expression of this referent on this tag. If locale
    # or form aren't specified, match any expression
    args[:form] = Expression.formnum(:generic) unless args[:form]
    if self.id
      Expression.find_or_create self.id, tag.id, args
    elsif self.expressions.empty? # We're not saved, so have no id
      args[:tag_id] = tag.id
      expr = Expression.new(args)
      self.expressions << expr
    end

    # Point the tag back at this referent, if needed
    tag.admit_meaning(self)
    tag.id
  end

  # Return a list of all tags that are related to the one provided. This means:
  # ...all the synonyms (if required) and
  # ...all the parents (if required) of
  # ...all the children (if required) of
  # ...all the referents of this tag
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

  # Find a referent from a tag string of a given type. This is a search
  # for ANY tag that refers to the the referent, not just the canonical one
  def self.find_by_tag tag, tagtype
    # Find or create the tag

    # We now have a list of qualifying tags. Choose the one which has
    # an existing referent, if any

    # Find or create an appropriate referent for the tag
  end

  # Remove uses of this tag by this referent
  def drop tag
    if self.tag_id == tag.id
      # Need to find another tag to use for canonical string
      return nil unless replacement_tag = self.tags.detect { |candidate| candidate.id != tag.id }
      self.canonical_expression = replacement_tag
    end
    self.tags.delete tag
    self.save
  end

  # Return the tag expressing this referent according to the given form and locale, if any
  def expression(args = {})
    args = Expression.scrub_args args
    ((args.size > 0) && (expr = self.expressions.where(args).first)) ?
        expr.tag :
        canonical_expression
  end

  # Return the name of the referent
  def normalized_name(args = {})
    (tag = self.expression args) ? tag.normalized_name : "**no tag**"
  end

  # Return the name of the referent
  def name(args = {})
    (tag = self.expression args) ? tag.name : "**no tag**"
  end

  # Provide an array of all the names of all the tags for this referent
  def names
    self.expressions.map(&:name)
  end

  # Return the name, appended with all associated forms
  def longname
    result = self.name
    aliases = self.tags.uniq.select { |tag| tag.id != self.tag_id }.map { |tag| tag.name }.join(", ")
    result << "(#{aliases})" unless aliases.blank?
    result
  end

  def make_parent_of child_ref
    children << child_ref unless children.include?(child_ref)
  end

  def suggests target_ref
    target_ref.save unless target_ref.id
    # author_referents << target_ref unless author_referents.include?(target_ref)
    referments.create(referee_type: target_ref.class.to_s, referee_id: target_ref.id) unless referments.where(referee_type: target_ref.class.to_s, referee_id: target_ref.id).exists?
    x=2
  end

  def suggests? target_ref
    referments.exists? referee_type: target_ref.type, referee_id: target_ref.id
  end
end

# Subclases for different types of referents

# An Ingredient may suggest a type of dish
class FoodReferent < Referent
  def self.fix
    FoodReferent.all.each { |ref| ref.type = 'IngredientReferent'; ref.save }
  end
end

class SourceReferent < Referent
  has_one :site, foreign_key: 'referent_id'

  attr_accessible :site

  def associate
    self.site
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
