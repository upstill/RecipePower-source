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

class UserRelation < ActiveRecord::Base
    belongs_to :follower, :class_name => 'User'
    belongs_to :followee, :class_name => 'User'
    
    validates_with UserRelationValidator
end
