class RecipePolicy < CollectiblePolicy
=begin
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
=end

  def piclist?
    true
  end

  def parse?
    true
  end

  def revise?
    true
  end

  def recipe_page?
    true
  end

=begin
  def capture?
    super
  end

  def editpic?
    super
  end

  def glean?
    super
  end

  def touch?
    super
  end

  def associated?
    super
  end

  def collect?
    super
  end

  def card?
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











