class TagPolicy < ApplicationPolicy
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

  def index?
    super
  end

  def associate?
    true
  end

  def owned?
    true
  end

  def associated?
    true
  end

  def define?
    true
  end

  def list?
    true
  end

  def typify?
    true
  end

  def match?
    true
  end

end
