class RegistrationPolicy < ApplicationPolicy

  def create?
    super
  end

  def new?
    super
  end

  def edit?
    super
  end

  def update?
    super
  end

  def destroy?
    super
  end

  def cancel?
    true
  end

end



