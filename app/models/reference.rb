class Reference < ActiveRecord::Base
  include Linkable
  include Referrable
  include Typeable
  
  attr_accessible :reference_type
  
  typeable( :reference_type, 
    Article: ["Article", 1],
    NewsItem: ["News Item", 2],
    Tip: ["Tip", 4],
    Video: ["Video", 8],
    Definition: ["Glossary Entry", 16]
  )
  
  def self.assert(uri, tag_or_referent, type=:Definition )
    if tag_or_referent.class == Tag
      rft = Referent.express tag_or_referent
    else
      rft = tag_or_referent
    end
    return nil unless rft
    
    me = self.find_or_initialize( url: uri )
    if me.errors.empty?
      me.referents << rft unless me.referents.exists?(id: rft.id)
      me.reference_type = self.typenum(type)
      me.save
    end
    me
  end
end
