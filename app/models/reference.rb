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
    
    link = Link.assert(uri, :Reference)
    if me = link.entity
      me.typenum = type
    else
      me = self.new reference_type: self.typenum(type)
    end
    me.referents << rft unless me.referents.exists? id: rft.id
    me.link = link
    me.save
    me
  end
end
