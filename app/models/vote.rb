class Vote < ActiveRecord::Base
  self.primary_keys = ["user_id", "entity_type", "entity_id"]

  attr_accessible :voter, :user_id, :entity, :entity_type, :entity_id

  belongs_to :voter, :class_name => "User", foreign_key: 'user_id'
  belongs_to :entity, :polymorphic => true

  # NB: A voted-on entity can access its voters with

  def self.vote entity, up, user
    vote = self.find_or_create_by user_id: user.id, entity_type: entity.class.to_s, entity_id: entity.id
    if vote.up != up
      vote.up = up
      vote.save
    end
    vote
  end

end
