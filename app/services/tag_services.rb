class TagServices
  
  attr_accessor :tag
  
  delegate :id, :typename, :name, :normalized_name, :primary_meaning, :isGlobal, 
    :users, :user_ids, :owners, :owner_ids, :reference_count, :referents, :can_absorb, :to => :tag
  
  def initialize(tag, user=nil)
    self.tag = tag
    @user = user || User.super_id
  end
# -----------------------------------------------    
  def recipe_ids with_synonyms=false
    with_synonyms ?
      Tag.where(id: ([id] + synonym_ids) ).collect { |tag| tag.recipe_ids }.flatten.uniq :
      tag.recipe_ids
  end
  
  def recipes with_synonyms=false
    Recipe.where(id: recipe_ids(with_synonyms) )
  end
# -----------------------------------------------    
  # Return the references associated with the tag. This includes all the references from synonyms of the tag
  def reference_ids
    tag.referents(true).collect { |referent| referent.reference_ids }.flatten.uniq
  end
  
  # Return the references associated with the tag. This includes all the references from synonyms of the tag
  def references
    Reference.where id: reference_ids
  end
  
  # Just return the count of references
  def reference_count
    reference_ids.count
  end
# -----------------------------------------------  
  def synonym_ids
    ExpressionServices.synonym_ids_of_tags(id) - [id]
  end
  
  def self.synonym_ids(ids)
    ExpressionServices.synonym_ids_of_tags(ids) - [ids].flatten
  end
  
  def synonyms
    Tag.where id: synonym_ids
  end
# -----------------------------------------------  
  def child_ids
    ExpressionServices.child_ids_of_tags(id) - [id]
  end
  
  def self.child_ids(ids)
    ExpressionServices.child_ids_of_tags(ids) - [ids].flatten
  end
  
  def children
    Tag.where id: child_ids
  end
# -----------------------------------------------    
  def parent_ids
    ExpressionServices.parent_ids_of_tags(id)
  end
  
  def self.parent_ids(ids)
    ExpressionServices.parent_ids_of_tags(ids)
  end
  
  def parents
    parent_ids.collect { |parent_set| Tag.where id: parent_set }
    # Tag.where id: parent_ids
  end
# -----------------------------------------------    
  # Return tags that match any of the given tags lexically, regardless of type
  def self.lexical_similars(tags)
    results = tags
    tags.each do |tag| 
      matches = Tag.strmatch(tag.name)
      results = results + (matches-results) if matches
    end
    results
  end
  
  def lexical_similars
    Tag.strmatch(tag.name).delete_if { |other| other.id == id }
  end
      
# -----------------------------------------------      
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


  # Class method meant to be run from a console, to clean up redundant tags (name/index pair not unique) before adding index to prevent them
  def self.qa
    Tag.all.each do |tag|
      if !tag.tagqa
        result = tag.errors[:key] && tag.disappear
      end
    end
  end

  def self.time_lookup ix=1
    label = ""
    index_name = index_table = nil
    tag_ids = Tag.all.map(&:id)
    time = Benchmark.measure do
      case ix
        when 1
          label = "Tag via ID"
          index_table = :tags
          index_name = "tags_index_by_id"
          tag_ids.each { |id|
            name = Tag.find(id).name
          }
        else
          return false
      end
    end
    index_status = ActiveRecord::Base.connection.index_name_exists?( index_table, index_name, false) ? "indexed" : "unindexed"
    File.open("db_timings", 'a') { |file|
      file.write(label+" (#{Time.new} #{index_status}): "+time.to_s+"\n")
    }
    true
  end

end
