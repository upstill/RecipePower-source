class FeedPolicy < ApplicationPolicy
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

  def refresh?
    true
  end

  def contents?
    true
  end

  def approve?
    true
  end

  def rate?
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

end
