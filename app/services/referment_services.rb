require 'page_ref.rb'

class RefermentServices

  attr_accessor :referment

  delegate :reference, :referent, :referee, :to => :referment

  def initialize(referment)
    self.referment = referment
  end

  def type_to_class type

  end

  def self.make_polymorphic
    Referment.all.each do |rfm|
      flat_reference = rfm.referent # class Reference
    end
  end

  def make_polymorphic

  end

  def self.convert_references
    Referment.where(referee_type: "Reference").each { |rm|
      RefermentServices.new(rm).convert_reference if rm.referee.class == DefinitionReference
    }
  end

  def convert_reference
    url = referment.referee.url.sub /www\.foodandwine\.com\/chefs\//, 'www.foodandwine.com/contributors/'
    if (referment.referee.class == DefinitionReference) && (pr = DefinitionPageRef.fetch(url))
      referment.referee = pr
      referment.save
    end
  end
end