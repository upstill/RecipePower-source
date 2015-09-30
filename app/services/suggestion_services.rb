require 'search_node'

class SuggestionServices
  # Build a suggestions finder for the given elements:
  # 'target_type' is an entity type (class of taggable or collectible)
  # 'viewer' is the user viewing the result
  # 'basis' is an entity to vector off of (i.e., recipes related to a specific recipe)
  # 'context' is the entity being viewed at the time (e.g., a user's collection, or the Big List)
  # 'querytags' are the tags being searched for at the moment
  def initialize target_type, viewer, basis=nil, context=nil, querytags = []
    master = EntityAssociator.build_root target_type, viewer
    master.build_child(basis, 1.0) if basis
    master.build_child(context, 1.0) if context
    querytags.each { |tag| master.build_child tag, 1.0 }
  end
end

class EntityAssociator
  include SearchNode

  def self.autobuild source_entity, target_entity_type, viewer, weight = 1.0, parent = nil
    # What class are we building?
    klass = (source_entity.class.to_s+"Associator").constantize
    klass.build source_entity, target_entity_type, viewer, weight, parent
  end

  def self.build source_entity, target_entity_type, viewer, weight = 1.0, parent = nil
    associate = self.class.new source_entity, target_entity_type, viewer
    parent ? parent.init_child_search(associate, weight) : init_search
    init_children
    sort_children
  end

  def self.build_root target_entity_type, viewer
    EntityAssociator.build nil, target_entity_type, viewer
  end

  def initialize source_entity, target_entity_type, viewer
    @source_entity = source_entity
    @target_entity_type = target_entity_type
    @viewer = viewer
  end

  def build_child source_entity, weight = 1.0
    EntityAssociator.autobuild(source_entity, @target_entity_type, @viewer, weight, self) if (weight*child_attenuation) >= sn_cutoff
  end

  def build_child_of_class klass, source_entity, weight = 1.0
    klass.build(source_entity, @target_entity_type, @viewer, weight, self) if (weight*child_attenuation) >= sn_cutoff
  end

  # This is a stub for any associators that want to pre-build their results
  def init_children

  end

end

class TaggableAssociator < EntityAssociator
  def init_children
    # For all tags that have been applied to the taggable
    # build_child tag, weight
    # For all lists upon which it appears
    # build_child list, weight
  end
end

class CollectibleAssociator < EntityAssociator
  def init_children
    # For each user who's collected it
    #   weight divided by two for non-friends
    #   build_child user, weight
    # build_child site, weight
  end
end

class TagAssociator < EntityAssociator
  def init_children
    # For all associated tags
    #   build_child tag, weight
    # For all entities that have been thus tagged
    #   build_child entity, weight
  end
end

class UserAssociator < EntityAssociator
  def init_children
    build_child_of_class ColletibleAssociator, self, weight
    build_child_of_class TaggableAssociator, self, weight
    # For each friend
    #   build_child friend, weight
    # For each owned list
    #   build_child list, weight
    # For each tag used
    #   build_child tag, weight
    # For each feed followed
    #   build_child feed, weight
  end
end

class FeedAssociator < EntityAssociator
  def init_children
    build_child_of_class ColletibleAssociator, self, weight
    build_child_of_class TaggableAssociator, self, weight
  end
end

class SiteAssociator < EntityAssociator
  def init_children
    build_child_of_class ColletibleAssociator, self, weight
    build_child_of_class TaggableAssociator, self, weight
    # For each feed on the site
    #   build_child feed, weight
    # For each user who's collected things on the site
    #   build_child user, weight

  end
end

class ListAssociator < EntityAssociator
  def init_children
    build_child_of_class ColletibleAssociator, self, weight
    build_child_of_class TaggableAssociator, self, weight
  end
end

class UserAssociator < EntityAssociator

end