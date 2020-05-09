class TagPolicy < ApplicationPolicy
  def create?
    @user.is_user?
  end

  def new?
    @user.is_user?
  end

  def edit?
    update?
  end

  def show?
    true
  end

  def update?
    @user.is_editor?
  end

  def destroy?
    @user.is_editor?
  end

  def index?
    true
  end

  def associate?
    @user.is_editor?
  end

  def owned?
    @user.is_user?
  end

  def associated?
    true
  end

  def define?
    @user&.is_editor?
  end

  def list?
    true
  end

  def typify?
    @user&.is_editor?
  end

  def match?
    true
  end

end
