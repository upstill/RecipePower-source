class Link < ActiveRecord::Base
    has_many :link_refs
    has_many :tags, :through=>:link_refs
    attr_accessible :domain, :uri, :resource_type
    
    @@TypeToSym = [nil, :vendor, :store, :book, :blog, :rcpsite, :cookingsite, :othersite, :video, :glossary]
    @@TypeToString = ["Untyped Link", "Supplier", "Store Location", "Book", "Blog", "Recipe Site", "Cooking Site", "Other Site", "Video", "Glossary"]
    
    # Return the integer type key for the given symbol
    def self.sym_inDB(sym)
        @@TypeToSym.index(sym)
    end
    
    # Return the integer type key for the given string
    def self.string_inDB(str)
        @@TypeToString.index(str)
    end
    
    # Convert a type specifier (whether a symbol or string or integer) into an integer
    def self.resource_type_inDB(t)
        unless t.kind_of? Integer
            t = (t.kind_of? Symbol) ? self.sym_inDB(t) : self.string_inDB(t)
        end
        t
    end
    
    # Assign to the 'type' field. NB: will accept a token
    def resource_type=(t)
        t = Link.resource_type_inDB(t)
        super
    end
    
    # Get the link's type as either a symbol, a string or an integer
    def resource_type_as(id)
        self.resource_type = 0 if self.resource_type.nil?
        if(id==Symbol)
            @@TypeToSym[self.resource_type]
        elsif(id==String)
            @@TypeToString[self.resource_type]
        elsif(id==Fixnum)
            self.resource_type
        end
    end
    
    # Match the link's type against either an integer type or a symbol or string
    def resource_type_is(t)
        Link.resource_type_inDB(t) == self.resource_type
    end
end
