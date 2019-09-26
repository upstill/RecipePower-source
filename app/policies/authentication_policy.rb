class AuthenticationPolicy < ApplicationPolicy

# Authentication Policy: let Devise handle it

  def index?
    true
  end

  def create?
    true
  end

  def new?
    true
  end

  def edit?
    true
  end

  def show?
    true
  end

  def update?
    true
  end

  def destroy?
    true
  end

  def failure?
    true
  end

end



