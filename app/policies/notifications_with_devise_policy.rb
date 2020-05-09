class NotificationsWithDevisePolicy < ApplicationPolicy

  def index?
    super
  end

  def show?
    super
  end

  def destroy?
    super
  end

  def open_all?
    true
  end

  def move?
    true
  end

  def open?
    true
  end

end
