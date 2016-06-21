class Referment < ActiveRecord::Base

  attr_accessible :referent, :referee, :referee_type

  belongs_to :referent
  belongs_to :referee, :polymorphic => true
  
end
