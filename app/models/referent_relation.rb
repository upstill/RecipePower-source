class ReferentRelationValidator < ActiveModel::Validator
    def validate(record)
        unless record.parent_id
            record.errors[:parent_id] << "Relation must include parent"
            return false
        end
        unless record.child_id
            record.errors[:child_id] << "Relation must include child"
            return false
        end
        parent = Referent.find record.parent_id
        child = Referent.find record.child_id
        unless parent.type == child.type
            record.errors[:base] << "Parent and child must be of same type"
            return false
        end
        return true;
    end
end

class ReferentRelation < ActiveRecord::Base
    belongs_to :parent, :class_name => "Referent"
    belongs_to :child, :class_name => "Referent"
    
    validates_with ReferentRelationValidator
end
