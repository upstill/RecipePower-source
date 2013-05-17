class ReferentServices
  
  def initialize(referent)
    @referent = referent
  end
  
  # Return the ids of referents directly descended from those given (as an id or ids)
  def self.direct_child_ids(ref_ids)
    ReferentRelation.where(parent_id: ref_ids).map(&:child_id) - [ref_ids].flatten
  end
  
  def self.direct_parent_ids(ref_ids)
    ReferentRelation.where(child_id: ref_ids).map(&:parent_id) - [ref_ids].flatten
  end

end