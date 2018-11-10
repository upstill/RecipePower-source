require 'page_ref.rb'

class RefermentServices

  attr_accessor :referment

  delegate :referent, :referee, :to => :referment

  def initialize(referment)
    self.referment = referment
  end

  def type_to_class type

  end

  def self.make_polymorphic
    Referment.all.each do |rfm|
      flat_reference = rfm.referent
    end
  end
  
end
