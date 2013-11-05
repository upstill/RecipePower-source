require "type_map.rb"
# Management of type fields made easy
module Typeable
  extend ActiveSupport::Concern

  module ClassMethods
    
    def typeable(attribute, list)
      @tag_types = TypeMap.new(list, "unclassified")
      @attrib_name = attribute
    end
    
    # Get the type number, taking any of the accepted datatypes
    def typenum tt
        @tag_types.num tt
    end
    
    # Get the symbol for the type, taking any of the accepted datatypes
    def typesym tt
        @tag_types.sym tt
    end
    
    # Get the name for the type, taking any of the accepted datatypes
    def typename tt
        @tag_types.name tt
    end
    
    # Return a list of name/type pairs, suitable for making a selection list
    def type_selections(withnull=false)
      range = withnull ? 0..-1 : 1..-1
      @tag_types.list.compact[range]
    end
    
    def attrib_name
      @attrib_name
    end

    # Taking an index into the table of tag types, return the symbol for that type
    # (used to build a set of tabs, one for each tag type)
    # NB: returns nil for nil index and for index beyond the last type. This is useful
    # for generating a table that covers all types
    def index_to_type(index)
        index if index && (index <= @tag_types.max_index)
    end
  end
  
    def self.included(base)
      base.extend(ClassMethods)
    end 
    
    def typenum
        self.read_attribute self.class.attrib_name # self.tagtype
    end
    
    def typenum=(tt)
        self.attributes = { self.class.attrib_name => self.class.typenum(tt) }
    end
    
    # Return the symbol for the type of self
    def typesym
      self.class.typesym typenum
    end
    
    # Return the name for the type of self
    def typename
      self.class.typename typenum
    end

    # Is my tagtype the same as the given type(s) (given as string, symbol, integer or array)
    def typematch(tt=nil)
        return true if tt.nil? # nil type matches any tag type
        if tt.kind_of?(Array)
            tt.any? { |type| self.typematch type }
        else
            self.class.typenum(tt) == typenum
        end
    end
end