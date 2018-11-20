class UserRelationValidator < ActiveModel::Validator
  def validate(record)
    unless record.follower_id
      record.errors[:follower_id] << 'Relation must include follower'
      return false
    end
    unless record.followee_id
      record.errors[:followee_id] << 'Relation must include followee'
      return false
    end
    return true;
  end
end

class UserRelation < ApplicationRecord
  belongs_to :follower, :class_name => 'User'
  belongs_to :followee, :class_name => 'User'

  @@FolloweeCache = {}

  validates_with UserRelationValidator

  # Provide the list of ids for the folowees of the given id
  def self.followee_ids_of id
    @@FolloweeCache[id] ||= self.where(follower_id: id).pluck :followee_id
  end
  
  end
