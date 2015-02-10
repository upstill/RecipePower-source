class CollectibleServices

  attr_accessor :entity

  delegate :owner, :ordering, :name, :name_tag, :tags, :notes, :availability, :owner_id, :to => :entity

  def initialize entity
    self.entity = entity
  end

  # Return the list of users who have collected this entity
  def collectors
    Rcpref.where(entity: entity, private: false, in_collection: true).includes(:user).map &:user
  end
end