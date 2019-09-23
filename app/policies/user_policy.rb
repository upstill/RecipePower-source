class UserPolicy < ApplicationPolicy
  def index?
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

  def profile?
    true
  end

  def identify?
    true
  end

  def recent?
    true
  end

  def collection?
    true
  end

  def biglist?
    true
  end

  def match_friends?
    true
  end

  def notify?
    true
  end

  def acquire?
    true
  end

  def follow?
    true
  end

  def getpic?
    true
  end

  def sendmail?
    true
  end

  def unsubscribe?
    true
  end

  def editpic?
    true
  end

  def glean?
    true
  end

  def tag?
    true
  end

  def lists?
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

end
