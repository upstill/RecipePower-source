module TaggableActions
  def prep_params entity = nil
    taggable_entity = super
    taggable_entity.prep_params @user.id
    taggable_entity
  end

  def accept_params entity = nil
    taggable_entity = super
    taggable_entity.accept_params
    taggable_entity
  end
end