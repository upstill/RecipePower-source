class RegistrationPolicy < ApplicationPolicy
# Registration Policy: let Devise deal with it
=begin
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
=end

  def cancel?
    true
  end

end



