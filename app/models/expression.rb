class ExpressionValidator < ActiveModel::Validator
    def validate(record)
        debugger
        if(record.tag_id && record.referent_id)
            tag = Tag.find record.tag_id
            ref = Referent.find record.referent_id
            if tag.tagtype != ref.referent_type && (tag.tagtype > 0)
                record.errors[:tag_id] << "#{tag.name} is a '#{tag.typename}', not '#{Tag.typename(ref.referent_type)}'"
            end
        else
            record.errors[record.tag_id ? :referent_id : :tag_id] << "Must have both tag and referent ids."
        end
    end
end
    
class Expression < ActiveRecord::Base
    belongs_to :tag
    belongs_to :referent
    
    attr_accessible :tag_id, :referent_id, :locale, :form, :tagname, :tag_token
    
    validates_with ExpressionValidator
    
    after_find :symbolize
    
    @@FormTypes = { :corruption=>0, :canonical=>1 }
    
    # Ensure that the type is a proper integer
    def self.type_inDB(type)
        type = type.to_sym if type.class == String
        type.class == Symbol ? @@FormTypes[type] : type
    end
    
    def symbolize
        self.locale = self.locale.to_sym
    end
    
    def tagname
        return "**no tag**" unless self && self.tag
        self.tag.name
    end
    
    # Tag_token: a virtual attribute for taking tag specifications from tokenInput.
    # These will either be a tag key (integer) or a token string. Integers are easy;
    # If a token string, it has a type specifier for the tag prepended.
    # Before accepting a tag name as a new tag, we do our due diligence to find the
    # proferred string among 1) tags of the specified type, and 2) free (untyped) tags.
    def tag_token()
        self.tag_id && self.tag_id.to_s
    end
    
    def tag_token=(t)
        if (id = t.to_i) > 0
            self.tag_id = id
        else
            t.sub!(/^\'(.*)\'$/, '\1') # Strip out the single quotes
            params = t.split('::')
            tagtype = params.first.to_i
            tagname = params.last
            # Try to match all within the type
            tag = Tag.strmatch( tagname, tagtype: tagtype, matchall: true ).first ||
                  Tag.strmatch( tagname, assert: true ).first # Try to pick up a match from the free tags
            self.tag_id = tag.id
        end
        self.tag_id
    end
end
