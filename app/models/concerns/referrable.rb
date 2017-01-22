# A Referrable class can be linked to a Referent. 
# Referrable classes include (or should) Reference, Recipe, Feed, Feed Entry, Site, Offering, Image, DefinitionPageRef
module Referrable
  extend ActiveSupport::Concern

  included do
    has_many :referments, :dependent => :destroy, :as => :referee, :inverse_of => :referee
    has_many :referents, :through => :referments

    # Referent.referrable self
  end
  
end
