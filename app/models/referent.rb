class ReferentValidator < ActiveModel::Validator
    def validate(record)
        # Test that record has non-generic type
        unless record.type && record.type != "Referent"
            record.errors[:base] << "Referent can't have generic type"
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
    
    attr_accessible :tag, :type, :description, :isCountable, :expressions_attributes, :add_expression, :parent_tokens, :child_tokens
    
    # validates_associated :parents
    # validates_associated :children
    validates_with ReferentValidator
    
    before_save :ensure_expression
    after_save :ensure_tagtypes
    
    # Before saving a referent, we make sure its preferred tag is listed as an expression of type 1
    def ensure_expression
        # Look for an expression on this tag of type 1. If found, demote to a corruption (type 0)
        if self.canonical_expression
            unless self.expressions.any? { |exp| exp.tag_id == self.tag_id }
                # No expression found => make a new one and add it to the set
                self.expressions << Expression.create(:tag_id=>self.tag_id, :referent_id=>self.id, :form=>1, :locale=>:en)
            end
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
    
    @@Locales = [["English",:en], ["Italian",:it], ["Spanish",:es], ["French",:fr]]
    @@Forms = [["Generic", 1], ["Singular", 2], ["Plural", 3]]
    
    def self.locales
       @@Locales
    end
    
    def self.forms
       @@Forms
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
        self.parents = tag_tokens_to_referents(tokenlist).delete_if { |rel| (rel.id == self.id) && errors.add(:parents, "Can't be its own parent.") }
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
        self.children = tag_tokens_to_referents(tokenlist).delete_if { |rel| (rel.id == self.id)  && errors.add(:children, "Can't be its own child.") }
    end
    
    # Convert a list of referents into the tags that reference them.
    def tags_from_referents(referents)
        referents.collect { |ref| ref.canonical_expression }
    end
    
    # Convert a list of tag tokens into the referents to which they refer
    def tag_tokens_to_referents(tokens, use_existing=true)
        refs = tokens.collect do |token|
            # We either match the referent to token or create a new one
            token.strip!
            token = token.to_i unless token.sub!(/^\'(.*)\'$/, '\1')
            Referent.express token, self.typenum
        end
        puts "Tokens converted to referents: "+refs.inspect
        refs
    end
    
    # Class method to create a referent of a given type under the given tag.
    # WARNING: while some effort is made to find an existing referent and use that,
    #  this procedure lends itself to redundancy in the dictionary
    def self.express (tag, tagtype, args = {} )
        tag = Tag.assert_tag tag, tagtype: tagtype # Creating it if need be, and/or making it global 
        form = Expression.type_inDB :canonical
        # if there's already a referent referring to this tag, return it
        if exp = tag.expressions.where(:form=>form, :locale=>:en).first
            return exp.referent
        end
        unless result = tag.primary_meaning
            # Didn't find an existing referent, so need to make one
            result = tag.create_primary_meaning :type=>Referent.referent_class_for_tagtype(tagtype)
            result.express tag, form: :canonical, locale: :en
                # result.expressions.create :tag_id=>tagid, :form=>canonicalform, :locale=>:en
            # end
        end
        result
    end
    
    # Add a tag to the expressions of this referent, returning the tag id
    def express(tag, args = {})
        # We assert the tag in case it's
        # 1) specified by string or id, 
        # 2) of a different type, or 
        # 3) not already global
        tag = Tag.assert_tag tag, tagtype: self.typenum 
        form = Expression.type_inDB (args[:form] || :corruption)
        locale = args[:locale] || :en
        # unless self.expressions.any? { |exp| exp.tag_id==tagid && exp.form==form && exp.locale == locale }
        if self.expressions.where(tag_id: tag.id, form: form, locale: locale ).empty?
            self.expressions.create tag_id: tag.id, form: form, locale: locale
        end
        if (args[:form] == :canonical) || !self.canonical_expression
            self.canonical_expression = tag
            self.save
        end
        tag.id
    end
    
    # Return the tag expressing this referent, if any
    def expression(form = :canonical, locale = :en)
        return self.canonical_expression if (form == :canonical) && (locale == :en)
        # Otherwise, we need to lookup/makeup the appropriate expression
    end
    
    # Return a list of all tags that are related to the one provided. This means:
    # ...all the synonyms (if required) and
    # ...all the parents (if required) of
    # ...all the children (if required) of
    # ...all the referents of this tag
    def self.related tagid, doSynonyms = false, doParents = false, doChildren = false
        [Tag.find(tagid)].collect { |tag| 
            tag.referents.collect { |ref|
                (doSynonyms ? ref.tag_ids : []) +
                (doParents ? ref.parents.collect{ |parent| parent.tag_ids } : []) +
                (doChildren ? ref.children.collect{ |child| child.tag_ids } : [])
            }
        }.flatten.uniq.delete_if{ |id| id == tagid }.collect{ |id| Tag.find id }
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
    
    def self.referent_class_for_tagtype(tagtype)
        if(Tag.typenum(tagtype) > 0)
            Tag.typesym(tagtype).to_s+"Referent"
        else
            "Referent"
        end
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
    
    # Return the name of the referent [XXX for the current locale]
    def normalized_name
        self.canonical_expression ? self.canonical_expression.normalized_name : "**no tag**"
    end
    
    # Return the name of the referent [XXX for the current locale]
    def name
        self.canonical_expression ? self.canonical_expression.name : "**no tag**"
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

class GenreReferent < Referent ; end  

class RoleReferent < Referent ; end  

class ProcessReferent < Referent ; end 

class FoodReferent < Referent ; end  

class UnitReferent < Referent ; end  

class SourceReferent < Referent ; end  

class AuthorReferent < Referent ; end  

class OccasionReferent < Referent ; end  

class PantrySectionReferent < Referent ; end  

class StoreSectionReferent < Referent ; end  

class InterestReferent < Referent ; end  

class ToolReferent < Referent ; end  

