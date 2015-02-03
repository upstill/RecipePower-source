class ReferentServices
  
  def initialize(referent)
    @referent = referent
  end
  
  # Return the ids of referents directly descended from those given (as an id or ids)
  def self.direct_child_ids(ref_ids)
    ReferentRelation.where(parent_id: ref_ids).pluck(:child_id) - [ref_ids].flatten
  end
  
  def self.direct_parent_ids(ref_ids)
    ReferentRelation.where(child_id: ref_ids).pluck(:parent_id) - [ref_ids].flatten
  end
  
  # Change all canonical-expression uses of the tag at fromid to point to toid
  def self.change_tag(fromid, toid)
    Referent.where(tag_id: fromid).each do |ref| 
      ref.tag_id = toid
      ref.save
    end
  end

end