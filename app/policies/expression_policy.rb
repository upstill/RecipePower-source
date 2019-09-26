class ExpressionPolicy < ApplicationPolicy

  def index?
    super
  end

  def create?
    update?
  end

  def new?
    super
  end

  def edit?
    update?
  end

  def show?
    super
  end

  def update?
    @user&.is_editor?
  end

  def destroy?
    super
  end

end



