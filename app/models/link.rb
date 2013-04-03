require './lib/Domain.rb'

class Link < ActiveRecord::Base
    attr_accessible :domain, :uri, :resource_type
    
    belongs_to :entity, :polymorphic => true
    
    has_many :link_refs
    has_many :tags, :through=>:link_refs
    
    before_save :decode_link
    
    @@coder = HTMLEntities.new
    # Decode any HTML entities or escaped characters in the URI
    def decode_link
        # Ensure resource_type saved non-nil
        self.resource_type ||= 0
        # Get domain and path from url if not already there
        self.uri = @@coder.decode self.uri
        self.domain = domain_from_url self.uri
    end
    
    # Managing types of resource
    # NB: The resource_type indexes into these arrays
    @@TypeToSym = [:none, :vendor, :store, :book, :blog, :rcpsite, :cookingsite, :othersite, :video, :glossary, :recipe]
    @@TypeToString = ["untyped", "Supplier", "Store Location", "Book", "Blog", "Recipe Site", "Cooking Site", "Other Site", "Video", "Glossary", "Recipe"]
    
    # Convert a type specifier (whether a symbol or string or integer) into an integer
    def self.resource_type_inDB(t)
        return 0 if t.nil?
        unless t.kind_of? Integer
            t = (t.kind_of? Symbol) ? @@TypeToSym.index(t) :  @@TypeToString.index(t)
        end
        t
    end
    
    # Assign to the 'type' field. NB: will accept a token
    def resource_type=(t)
        t = Link.resource_type_inDB(t)
        super
    end
    
    # Return a human-readable string for the type of link
    def typestr()
        @@TypeToString[self.resource_type]
    end
    
    # Return a symbol for the link type
    def typesym()
        @@TypeToSym[self.resource_type]
    end
    
    # Match the link's type against either an integer type or a symbol or string
    def resource_type_is(t)
        Link.resource_type_inDB(t) == self.resource_type
    end
    
    # The moral equivalent of find_or_create_by_uri_and_type, with the sweetening of 
    #  taking a non-decoded uri and the option of specifying the type as symbol or string as 
    #  well as integer. Also, we will adopt an untyped link to the specified type if one
    #  doesn't already exist.
    def self.assert_link( uri, type = nil )
        # Find or create a matching link entry
        uri = @@coder.decode uri # Links are decoded in the database
        # Should be throwing an error if resource_type doesn't make sense
        resource_type = Link.resource_type_inDB type
        # Asserted type => type existing record if nil
        unless link = Link.find_by_uri_and_resource_type(uri, resource_type)
            if resource_type != 0 # Type was specified => look for untyped record to apply type to
                link = Link.find_or_create_by_uri_and_resource_type(uri, 0)
                link.resource_type = resource_type
                link.save
            else # Type was unspecified => look for any record that matches in uri
                link = Link.find_or_create_by_uri(uri)
            end
        end
        link
    end
end
