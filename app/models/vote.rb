class Vote < ActiveRecord::Base
  attr_accessible :user, :entity

  belongs_to :user
  belongs_to :entity, :polymorphic => true

  # NB: A voted-on entity can access its voters with

  def self.vote entity, up, user
    vote = find_or_create(user_id: user.id, entity_id: entity.id, entity_type: entity.class)
    if vote.up != up
      vote.up = up
      vote.save
    end
    vote
  end

end
