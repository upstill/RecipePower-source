class Referment < ActiveRecord::Base
  
  belongs_to :referent
  belongs_to :reference
  
end
