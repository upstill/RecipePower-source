class ReferentRelation < ActiveRecord::Base
    belongs_to :parent, :class_name => "Referent"
    belongs_to :child, :class_name => "Referent"
end
