class CollectiblePolicy < ApplicationPolicy
  # Policies for collectible entities
  # Not CRUD, but common enough
  #
  def card?
    true
  end

  def collect?
    @user&.is_user?
  end

  def lists?
    update? && @record.is_a?(Taggable)
  end

  def glean?
    @user&.is_user?
  end

  def editpic?
    update? && @record.is_a?(Picable)
  end

  def tag?
    @user&.is_user? && @record.is_a?(Taggable)
  end

  def touch?
    @user&.is_user?
  end

  def absorb?
    @user&.is_editor?
  end

  def associated?
    true
  end

  def capture?
    true # We'll let the controller sort it out
  end

end