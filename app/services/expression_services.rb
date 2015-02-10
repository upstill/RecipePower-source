class ExpressionServices
  def initialize(expression)
    @expression = expression
  end
  
  # Deliver referents for the (set of) tags
  def self.meaning_ids(tag_ids)
    Expression.where(tag_id: tag_ids).pluck :referent_id
  end
  
  def self.expression_ids(ref_ids)
    Expression.where(referent_id: ref_ids).pluck :tag_id
  end

  def self.expression_tags_from_ids(ref_ids)
    Expression.includes(:tag).where(referent_id: ref_ids).map(&:tag)
  end
  
  # Collect all the synonyms of all the tags denoted by id, excluding those
  # already in the set
  def self.synonym_ids_of_tags(tag_ids)
    # Get all the referents of all the tags
    refids = ExpressionServices.meaning_ids tag_ids
    # Return all the tags referred to by those
    ExpressionServices.expression_ids refids
  end
  
  # Return all the semantic children of the tag(s) as an array of arrays
  def self.child_ids_of_tags(tag_ids)
    # Get all the referents of all the tags
    refids = ExpressionServices.meaning_ids tag_ids
    child_refids = ReferentServices.direct_child_ids refids
    ExpressionServices.expression_ids child_refids
  end

  # Return all the semantic parents of the tag(s) as an array of arrays
  def self.parent_ids_of_tags(tag_ids)
    # Get all the referents of all the tags
    ExpressionServices.expression_ids ReferentServices.direct_parent_ids(ExpressionServices.meaning_ids tag_ids)
  end

  # Return all the semantic parents of the tag(s) as an array of arrays
  def self.parent_tags_of_tags(tag_ids)
    # Get all the referents of all the tags
    ExpressionServices.expression_tags_from_ids ReferentServices.direct_parent_ids(ExpressionServices.meaning_ids tag_ids)
  end

  # Return all the semantic siblings of the tag(s)
  def self.sibling_ids_of_tags(tag_ids)
    # Get all the referents of all the tags
    refids = ExpressionServices.meaning_ids tag_ids
    parent_refids = ReferentServices.direct_parent_ids refids
    sibling_refids = ReferentServices.direct_child_ids parent_refids
    ExpressionServices.expression_ids sibling_refids
  end

end