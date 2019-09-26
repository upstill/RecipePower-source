class EditionPolicy < ApplicationPolicy

  def index?
    super
  end

  def create?
    @user&.is_editor?
  end

  def new?
    super
  end

  def edit?
    @user&.is_editor?
  end

  def show?
    super
  end

  def update?
    edit?
  end

  def destroy?
    super
  end

end



