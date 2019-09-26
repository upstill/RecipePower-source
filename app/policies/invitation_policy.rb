class InvitationPolicy < ApplicationPolicy
=begin
  def edit?
    super
  end

  def destroy?
    super
  end

  def new?
    super
  end

  def update?
    super
  end

  def create?
    super
  end
=end

  def divert?
    true
  end

end



