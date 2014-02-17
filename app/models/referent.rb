class ReferentValidator < ActiveModel::Validator
    def validate(record)
        # Test that record has non-generic type
        unless record.type && record.type != "Referent"
            record.errors[:base] << "Referent can't have generic type"
            return false;
        end
        if record.tags.empty? && !record.canonical_expression
          record.errors[:base] << "A Referent must have at least one tag to express it."
          return false;
        end
        true
    end
end

class Referent < ActiveRecord::Base
    # Referents don't have a strict tree structure, just categories defined by an isa relationship.
    # This relationship is implemented by the ReferentRelation table, with parent_id and child_id keys
    has_many :child_relations, :foreign_key=>"parent_id", :dependent=>:destroy, :class_name=>"ReferentRelation"
    has_many :children, :through => :child_relations, :source => :child, :uniq => true 
    
    has_many :parent_relations, :foreign_key => "child_id", :dependent=>:destroy, :class_name => "ReferentRelation"
    has_many :parents, :through => :parent_relations, :source => :parent, :uniq => true

    has_many :expressions
    has_many :tags, :through=>:expressions
    accepts_nested_attributes_for :expressions, allow_destroy: true

    belongs_to :canonical_expression, :class_name => "Tag", :foreign_key => "tag_id"
    
    has_and_belongs_to_many :channels, :class_name => "Referent", :foreign_key => "channel_id", :join_table => "channels_referents", :uniq => true
    
    has_many :referments, :dependent => :destroy, :inverse_of => :referent
    has_many :references, :through => :referments, :source => :referee, :source_type => "Reference"
    has_many :recipes, :through => :referments, :source => :referee, :source_type => "Recipe"
    
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
    # By default, referents have no associate; currently, only Channels and Sources have one
    def associate
      nil
    end
    
    # Dump the contents of the database to stdout
    def self.dump tagtype=4
        Referent.all.collect { |ref| ref.parents.empty? && (ref.typenum==tagtype) && ref }.each { |tl| tl.dump if tl }
    end
    
    # Notify this referent of an association with some resource.
    # Since there's no intrinsic connection between any referents and any resources,
    # this one is strictly for overriding by subclasses
    def notice_resource(resource)
        # !!! This is where we pass a resource event to any associated channels !!!
        channels.each { |ch| ch.notice_resource resource }
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
                tag.links.each { |link| puts "#{indent}    Link #{link.id.to_s}: #{link.uri}"}
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
        self.parents = tag_tokens_to_referents(tokenlist).delete_if { |rel| (rel.id == self.id) && errors.add(:parents, "Can't be its own parent.") }.uniq
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
        self.children = tag_tokens_to_referents(tokenlist).delete_if { |rel| (rel.id == self.id)  && errors.add(:children, "Can't be its own child.") }.uniq
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
        puts "Tokens converted to referents: "+refs.inspect
        refs
    end
    
    def self.referent_class_for_tagtype(typenum)
      (((typenum > 0) ? Tag.typesym(typenum).to_s : "")+"Referent")
    end
    
    # Class method to create a referent of a given type under the given tag, 
    # or to find an existing one.
    # WARNING: while some effort is made to find an existing referent and use that,
    #  this procedure lends itself to redundancy in the dictionary
    def self.express (tag, tagtype = nil, args = {} )
        if tag.class == Tag # Creating it if need be, and/or making it global 
          tagtype = tag.tagtype
        else
          tag = Tag.assert_tag(tag, tagtype: tagtype) 
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
    def express(tag, args = {} )
        # We assert the tag in case it's
        # 1) specified by string or id, rather than a tag object
        # 2) of a different type, or 
        # 3) not already global
        tag = Tag.assert_tag tag, tagtype: self.typenum 
        
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
      tag_ids.uniq.delete_if{ |id| id == tag.id }.collect{ |id| Tag.find id }
    end

    def typesym
        self.type && self.type.sub( /Referent/, '').to_sym
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
            paths = paths + parent.paths_to(false,collected + [parent.id])
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
            parent = parent.parent if actuals[:mode] != "over"
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
        aliases = self.tags.uniq.select {|tag| tag.id != self.tag_id }.map { |tag| tag.name }.join(", ")
        result << "(#{aliases})" unless aliases.blank?
        result
    end
end

# Subclases for different types of referents

class FoodReferent < Referent ; 
    def self.fix
        FoodReferent.all.each { |ref| ref.type = "IngredientReferent"; ref.save }
    end
end  

class SourceReferent < Referent ; 
    has_one :site, foreign_key: "referent_id"
    
    attr_accessible :site
    
    def associate
      self.site
    end
end  

class ChannelReferent < Referent ; 
  has_one :user    
  attr_accessible :user, :tag_token, :user_attributes
  accepts_nested_attributes_for :user
  
  before_validation :check_tag
  after_save :fix_user

  def initialize *args
    super *args
    # Each channel gets a corresponding user with the super-user password
    self.user = User.find(User.super_id).dup
    user.email = "channels@recipepower.com"
    user.channel = self
  end
  
  def associate
    self.user
  end
  
  # The tag_tokens VA is special to channels, since 1) the name of the channel could
  # refer to a referent of another type (for dependent channels) and 2) a tag may or
  # may not be appropriate.
  def tag_tokens
      [canonical_expression].compact
  end
  
  def tag_tokens=(tokenlist)
    if token = tokenlist.split(',').first
      token.strip!
      if token.sub!(/^\'(.*)\'$/, '\1') || (token.to_i == 0) # A quote-delimited string a la tokeninput
        self.canonical_expression = Tag.assert_tag token, tagtype: self.typenum # Creating it if need be, and/or making it global 
      else
        self.canonical_expression = Tag.find token.to_i # Existing tag
      end
    end
  end
  
  # When a resource is tagged with one of this referent's tags, add it to the collection of the channel user
  def notice_resource(resource)
    resource.kind_of?(Recipe) && user && (resource.touch(true, user.id))
  end
  
  # For a channel based on another class of referent, the tag must have an associated referent, or
  # at least have a type so that a referent can be created.
  # For a freestanding channel, the tag CANNOT have an existing type (other than 'unclassified')
  def check_tag
      # At this point in the history of a channel, it presumably has a canonical expression.
      # We need to check that type

      return if !(tag = canonical_expression) # All referents must have a tag; this error will get picked up elsewhere
      # ensure_user
      # self.canonical_expression = self.expressions.first.tag unless self.canonical_expression || self.expressions.empty?
      # user.username = canonical_expression.name
      user.username = tag.name
      if @dependent # We're saving from editing
          if @dependent == "1"
              # The tag needs to be a type OTHER than 'unclassified' or 'Channel'
              if [0,11].include? tag.typenum
                  errors.add(:tags, "If you want a channel based on another type, you need to give it a name from that type. #{tag.name} is a #{tag.typename}")
              end
          elsif [0,11].include? tag.typenum
              # Since we're not dependent, we ensure we have a tag and make ourself our own channel
              express tag
              channels << self
          else
              # Error: channel is not dependent on another type
              errors.add(:tags, "You're giving this channel a name that already exists for a #{tag.typename}. Either create the channel with a unique name, or make the channel Dependent.")
          end
      end
  end

  # after_save method to correct the channel's user's email address
  def fix_user
    # Need to make sure the tag is linked to self
    tag = self.canonical_expression
    if @dependent == "1"
      # We're coming out of editing. Now that we're saved, it's safe to
      # add ourself to the channels of the (foreign) tag
      ref = Referent.express tag, tag.typenum
      ref.channels << self
      ref.save
    end
    if self.user.email == "channels@recipepower.com"
      self.user.email = "channel#{self.id.to_s}@recipepower.com"
      self.user.save
    end
  end
end  

class InterestReferent < ChannelReferent ; end

class GenreReferent < Referent ; end  

class RoleReferent < Referent ; end  

class ProcessReferent < Referent ; end 

class IngredientReferent < Referent ; end  

class UnitReferent < Referent ; end  

class AuthorReferent < Referent ; end  

class OccasionReferent < Referent ; end  

class PantrySectionReferent < Referent ; end  

class StoreSectionReferent < Referent ; end  

class ToolReferent < Referent ; end  

class NutrientReferent < Referent ; end  

class CulinaryTermReferent < Referent ; end  
