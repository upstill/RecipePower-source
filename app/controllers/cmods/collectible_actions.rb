module CollectibleActions
  def prep_params entity = nil
    collectible_entity = super
    collectible_entity.prep_params @user.id
    collectible_entity
  end

  def accept_params entity = nil
    collectible_entity = super # Get the requisite entity
    collectible_entity.accept_params if collectible_entity # Propagate the collection ref fields to the wide world
    collectible_entity
  end
end