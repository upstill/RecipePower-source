class TagServices
  
  attr_accessor :tag
  
  delegate :id, :name, :to => :tag
  
  def initialize(tag, user=nil)
    self.tag = tag
    @user = user || User.super_id
  end
  
  def synonym_ids
    ExpressionServices.synonym_ids_of_tags(id) - [id]
  end
  
  def self.synonym_ids(ids)
    ExpressionServices.synonym_ids_of_tags(ids) - [ids].flatten
  end
  
  def synonyms
    Tag.where id: synonym_ids
  end
  
  def child_ids
    ExpressionServices.child_ids_of_tags(id) - [id]
  end
  
  def self.child_ids(ids)
    ExpressionServices.child_ids_of_tags(ids) - [ids].flatten
  end
  
  def children
    Tag.where id: child_ids
  end
  
  def parent_ids
    ExpressionServices.parent_ids_of_tags(id) - [id]
  end
  
  def self.parent_ids(ids)
    ExpressionServices.parent_ids_of_tags(ids) - [ids].flatten
  end
  
  def parents
    Tag.where id: parent_ids
  end
  
  # Analyze the tag or set of tags for semantic neighbors, returning a list of 
  # tag/weight pairs.
  # ...a tag in the original set and its synonyms get a weight of 1
  # ...semantic children of the originals get weight 1/2
  # ...semantic parents of the originals get weight 1/3
  def self.semantic_neighborhood(tag_ids, min_weight = 0.4)
    result = Hash.new
    new_tag_ids = self.synonym_ids(tag_ids) + [tag_ids].flatten
    weight = 1.0
    until new_tag_ids.empty? || (weight < min_weight) do
      new_tag_ids.each { |tagid| result[tagid] = weight }
      new_tag_ids = self.child_ids(new_tag_ids) - result.keys
      weight = weight/2
    end
    result
  end
  
  # Look for and return tags that match any of the given tags lexically, regardless of type
  def self.lexical_neighborhood(tags)
    results = tags
    tags.each do |tag| 
      matches = Tag.strmatch(tag.name)
      results = results + (matches-results) if matches
    end
    results
  end
end