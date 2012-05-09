class Expression < ActiveRecord::Base
    belongs_to :tag
    belongs_to :referent
    
    attr_accessible :tag_id, :referent_id, :locale, :form, :tagname
    
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
end
