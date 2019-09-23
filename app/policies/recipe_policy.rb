class RecipePolicy < ApplicationPolicy
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

  def piclist?
    true
  end

  def capture?
    true
  end

  def parse?
    true
  end

  def editpic?
    true
  end

  def glean?
    true
  end

  def touch?
    true
  end

  def associated?
    true
  end

  def collect?
    true
  end

  def card?
    true
  end

  def tag?
    true
  end

  def lists?
    true
  end

  def revise?
    true
  end
end











