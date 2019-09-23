class AuthenticationPolicy < ApplicationPolicy

  def index?
    super
  end

  def create?
    super
  end

  def new?
    super
  end

  def edit?
    super
  end

  def show?
    super
  end

  def update?
    super
  end

  def destroy?
    super
  end

  def failure?
    true
  end

end



