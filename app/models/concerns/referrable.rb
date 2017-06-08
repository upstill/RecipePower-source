# A Referrable class can be linked to a Referent. 
# Referrable classes are subclasses of PageRef, not including Recipe and Site (which have their own semantics)
module Referrable
  extend ActiveSupport::Concern

  included do
    has_many :referments, :dependent => :destroy, :as => :referee, :inverse_of => :referee
    has_many :referents, :through => :referments

    # Referent.referrable self
  end
  
end
