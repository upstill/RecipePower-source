class Reference < ActiveRecord::Base
  include Linkable
  include Referrable
  include Typeable
  include Picable

  picable(:url) # Use the url attribute for the pic, and provide a corresponding thumbnail

  attr_accessible :reference_type
  
  typeable( :reference_type, 
    Article: ["Article", 1],
    Newsitem: ["News Item", 2],
    Tip: ["Tip", 4],
    Video: ["Video", 8],
    Definition: ["Glossary Entry", 16],
    Homepage: ["Home Page", 32],
    Product: ["Product", 64],
    Offering: ["Offering", 128],
    Recipe: ["Recipe", 256],
    Image: ["Image", 512],
    Site: ["Site", 1024]
  )
  
  def self.assert(uri, tag_or_referent, type=:Definition )
    if (me = self.find_or_initialize( url: uri )).errors.empty?
      me.assert tag_or_referent, type
    end
    me
  end

  def assert tag_or_referent, type=:Definition
    return nil unless rft =
        case tag_or_referent
          when Tag
            Referent.express tag_or_referent
          else
            tag_or_referent
        end
    self.referents << rft unless referents.exists?(id: rft.id)
    self.reference_type = Reference.typenum type
    save
  end

end
