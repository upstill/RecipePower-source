class Referment < ActiveRecord::Base
  
  belongs_to :referent
  belongs_to :referee, :polymorphic => true
  
end
