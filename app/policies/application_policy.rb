class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def index?
    true
  end

  def show?
    true
  end

  def create?
    !@user.nil?
  end

  def new?
    create?
  end

  def update?
    @user&.editor?
  end

  def edit?
    update?
  end

  def destroy?
    @user&.admin?
  end

  # All other actions are denied by default
  def method_missing(meth, *args, &block)
    false
  end

  class Scope
    attr_reader :user, :scope

    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      scope.all
    end
  end

  def defer_invitation?
    true
  end

  def menu?
    true
  end

end

