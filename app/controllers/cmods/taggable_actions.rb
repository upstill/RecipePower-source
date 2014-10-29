module TaggableActions
  def prep_params
    taggable_entity = super
    taggable_entity.define_user_taggings @user.id
    taggable_entity
  end

  def accept_params
    taggable_entity = super
    taggable_entity.accept_user_taggings
    taggable_entity
  end
end