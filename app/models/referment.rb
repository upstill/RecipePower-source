class Referment < ActiveRecord::Base

  attr_accessible :referent, :referent_id, :referee, :referee_type, :referee_id

  # Virtual attributes for creating the referee
  attr_accessible :url, :kind, :title
  attr_accessor :url, :kind, :title

  belongs_to :referent
  belongs_to :referee, :polymorphic => true, validate: true
  
end
