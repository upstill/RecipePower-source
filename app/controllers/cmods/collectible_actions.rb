module CollectibleActions
  def prep_params
    collectible_entity = super
    collectible_entity.define_collectible_attributes @user.id
    collectible_entity
  end

  def accept_params
    collectible_entity = super # Get the requisite entity
    collectible_entity.accept_collectible_attributes if collectible_entity # Propagate the collection ref fields to the wide world
    collectible_entity
  end
end