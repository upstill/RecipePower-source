class UserPolicy < CollectiblePolicy
=begin
  def index?
    super
  end

  def show?
    super
  end
=end

  def new?
    true # Deferring to Devise
  end

  def create?
    true # Deferring to Devise
  end

  def edit?
    update?
  end

  def destroy?
    @user&.is_admin? || (@user == @record) # Users can destroy themselves
  end

  def update?
    # A user can update themself, and an admin can update anybody
    @user&.is_user? && ((@user == @record) || @user.is_admin?)
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
    @user&.is_user?
  end

  def getpic?
    true
  end

  def sendmail?
    @user&.is_user?
  end

  def unsubscribe?
    @user&.is_user?
  end

=begin
# Collectible actions

  def editpic?
    super
  end

  def glean?
    super
  end

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

=end

end
