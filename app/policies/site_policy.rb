class SitePolicy < CollectiblePolicy
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
=end

  def feeds?
    true
  end

  def approve?
    @user&.is_editor?
  end

=begin
  def touch?
    super
  end

  def card?
    super
  end

  def collect?
    super
  end

  def absorb?
    super
  end

  def editpic?
    super
  end

  def glean?
    super
  end

  def associated?
    super
  end

  def tag?
    super
  end

  def lists?
    super
  end
=end

end
