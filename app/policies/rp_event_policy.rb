class RpEventPolicy < ApplicationPolicy
=begin
  def show?
    super
  end

  def index?
    super
  end

  def new?
    super
  end

  def create?
    super
  end

  def update?
    super
  end

  def destroy?
    super
  end
=end

  def show_page?
    true
  end

end



