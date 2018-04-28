class ReferentServices
  
  def initialize(referent)
    @referent = referent
  end
  
  # Return the ids of referents directly descended from those given (as an id or ids)
  def self.direct_child_ids(ref_id_or_ids)
    ReferentRelation.where(parent_id: ref_id_or_ids).pluck(:child_id) - [ref_id_or_ids].flatten
  end
  
  def self.direct_parent_ids(ref_id_or_ids)
    ReferentRelation.where(child_id: ref_id_or_ids).pluck(:parent_id) - [ref_id_or_ids].flatten
  end

  # Return the ontological parentage from one referent id to another, if such a path exists
  # Result: an ordered array of referents, higher to lower in the hierarchy (i.e, starting with other and ending with self)
  def self.id_path path, higher_id
    if path.last == higher_id # Found!
      return path
    elsif path.include?(higher_id) # No cycles, please
      return nil
    else
      # Try each parent id in turn to see if it completes a path
      self.direct_parent_ids(path.last).inject(nil) { |result, parent_id|
        result || self.id_path(path << parent_id, higher_id)
      }
    end
  end

  # Provide an array of referents denoting the lineage from 'other' to this referent
  def ancestor_path_to other
    if path = ReferentServices.id_path([@referent.id], other.id)
      path.collect { |rid|
        case rid
          when @referent.id
            @referent
          when other.id
            other
          else
            Referent.find_by id: rid
        end
      }
    end
  end

=begin
  # Return the transitive closure of the referent's ancestors
  def ancestor_ids &block
    newset = @referent.parent_ids
    ancestor_ids = []
    while newset.present? do
      ancestor_ids |= newset
      newset = ReferentRelation.where(child_id: newset).pluck :parent_id
      if (circularities = newset & ancestor_ids).present?
        # GAH! Parent(s) appear which have already been checked! Circularity!!!
        if block.present?
          yield @referent, circularities
        else
          newset -= circularities
        end
      end
    end
    return ancestor_ids
  end

  def ancestor_ids!
    ancestor_ids do  |ref, circularities|
      msg = "Ref '#{ref.name}' (#{ref.id}) has circularity in its ancestry with" +
          Referent.where(id: circularities).collect { |ref| "'#{ref.name}' (#{ref.id})" }.join(' and ')
      throw msg
    end
  end
=end

  # Change all canonical-expression uses of the tag at fromid to point to toid
  def self.change_tag(fromid, toid)
    Referent.where(tag_id: fromid).each { |ref| ref.update_attribute :tag_id, toid }
  end


end