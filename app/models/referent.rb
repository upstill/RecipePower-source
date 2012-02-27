class Referent < ActiveRecord::Base
    acts_as_tree
    
    has_many :expressions
    has_many :tags, :through=>:expressions
    
    attr_accessible :tag, :type
    
    before_save :ensure_expression
    
    # Before saving a referent, we make sure its preferred tag is listed as an expression of type 1
    def ensure_expression
        # Look for an expression on this tag of type 1. If found, demote to a corruption (type 0)
        unless self.expressions.any? { |exp| exp.tag_id == self.tag }
            # No expression found => make a new one and add it to the set
            self.expressions << Expression.create(:tag_id=>self.tag, :referent_id=>self.id, :form=>1, :locale=>:en)
        end
    end
    
    def referent_type
        Tag.tagtype_inDB self.class.name.sub /Referent/, ''
    end
        
public
    
    def self.show_tree(*params)
        children = []
        level = 0
        if key = params.first
            level = params[1] || 0
            ref = Referent.find(key)
            puts ("    "*level)+"#{ref.id.to_s}: #{ref.name} (#{ref.tag})"
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
    
    # Class method to create a referent under the given tag.
    # WARNING: while some effort is made to find an existing referent and use that,
    #  this procedure lends itself to redundancy in the dictionary
    def self.express (tagstring, tagtype, *params)
        # unless tagtype = params.first
            # tagtype = Tag.tagtype_inDB self.name.sub(/Referent/,'')
        # end
        tagid = Tag.ensure_tag tagstring, tagtype, true
        canonicalform = Expression.type_inDB :canonical
        tag = Tag.find tagid
        # if there's already a referent referring to this tag, return it
        if exp = tag.expressions.where(:form=>canonicalform, :locale=>:en).first
            return self.find exp.referent_id
        end
        # Didn't find an existing referent, so need to make one
        result = self.create :tag=>tagid, :type=>tagtype.to_s+"Referent"
        result.express tagstring, :canonical, :en
        # unless self.expressions.where(:tag_id=>tagid, :form=>canonicalform, :locale=>:en).first
            # result.expressions.create :tag_id=>tagid, :form=>canonicalform, :locale=>:en
        # end
        result
    end
    
    # Add a tag to the expressions of this referent, returning the tag id
    def express(tag, *params)
        tagid = Tag.ensure_tag tag, self.referent_type, true
        form = Expression.type_inDB (params[0] || :corruption)
        locale = params[1] || :en
        # unless self.expressions.any? { |exp| exp.tag_id==tagid && exp.form==form && exp.locale == locale }
        unless self.expressions.where(tag_id: tagid, form: form, locale: locale ).first
            self.expressions.create tag_id: tagid, form: form, locale: locale
            if params[0] == :canonical
                self.tag = tagid 
                self.save
            end
        end
        tagid
    end
    
    # Return the name of the referent [XXX for the current locale]
    def name
        tag = Tag.find self.tag
        tag.name
    end
    
    # Return the name, appended with all associated forms
    def longname
        result = self.name
        aliases = self.tags.uniq.select {|tag| tag.id != self.tag }.map { |tag| tag.name }.join(", ")
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

