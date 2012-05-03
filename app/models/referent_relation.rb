class ReferentRelation < ActiveRecord::Base
    belongs_to :referent
    belongs_to :reference, :class_name => "Referent"
end
