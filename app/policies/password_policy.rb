class PasswordPolicy < ApplicationPolicy

# Password Policy: let Devise handle security

  def new?
    true
  end

  def edit?
    true
  end

  def update?
    true
  end

  def create?
    true
  end

end



