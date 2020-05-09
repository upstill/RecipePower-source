class FeedEntryPolicy < CollectiblePolicy

=begin

  def edit?
    super
  end

  def show?
    super
  end

  def update?
    @user&.is_user?
  end

  def destroy?
    super
  end
=end

=begin

  def tag?
    super
  end

  def lists?
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

  def editpic?
    super
  end

  def glean?
    super
  end
=end

end



