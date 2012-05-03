class ReferentRelation < ActiveRecord::Base
    belongs_to :referent
    belongs_to :child, :class_name => "Referent"
end
