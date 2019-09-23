class AdminPolicy < ApplicationPolicy

  def toggle?
    true
  end

  def data?
    true
  end

  def control?
    true
  end

end
