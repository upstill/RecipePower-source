require 'search_node'

class SuggestionServices
  include SearchNode

  # Build a suggestions finder for the given elements:
  # 'target_type' is an entity type (class of taggable or collectible)
  # 'viewer' is the user viewing the result
  # 'basis' is an entity to vector off of (i.e., recipes related to a specific recipe)
  # 'context' is the entity being viewed at the time (e.g., a user's collection, or the Big List)
  # 'querytags' are the tags being searched for at the moment
  def initialize target_type, viewer, basis=nil, context=nil, querytags = []

  end
end

class ViewerSugs
  def initialize target_type, basis=nil, context=nil, querytags = []

  end
end

class EntityAssociator
  include SearchNode
  
  def self.build source_entity, target_entity_type, viewer, parent = nil
    # What class are we building?
    klass = (source_entity.class.to_s+"Associator").constantize
    associate = klass.new source_entity, target_entity_type, viewer
    parent ? parent.init_child_search(associate, associate.weight) : init_search
  end
  
  def initialize source_entity, target_entity_type, viewer
    @source_entity = source_entity
    @target_entity_type = target_entity_type
    @viewer = viewer
  end

  def build_child source_entity, target_entity_type, viewer
    self.class.build source_entity, target_entity_type, viewer, self
  end

end

class TaggableAssociator < EntityAssociator
end

class CollectibleAssociator < EntityAssociator
  def initialize source_entity, target_entity_type, viewer

  end
end

class TagAssociator < EntityAssociator

  def initialize source_entity, target_entity_type, viewer

  end
end

class UserAssociator < EntityAssociator

  def initialize source_entity, target_entity_type, viewer

  end
end

class FeedAssociator < EntityAssociator

  def initialize source_entity, target_entity_type, viewer

  end
end

class UserAssociator < EntityAssociator

  def initialize source_entity, target_entity_type, viewer

  end
end

class UserAssociator < EntityAssociator

  def initialize source_entity, target_entity_type, viewer

  end
end

class UserAssociator < EntityAssociator

  def initialize source_entity, target_entity_type, viewer

  end
end