class Referment < ActiveRecord::Base

  attr_accessible :referent, :referee, :referee_type, :referee_id

  belongs_to :referent
  belongs_to :referee, :polymorphic => true, validate: true
  
end
