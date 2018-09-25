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

  def self.show_definitions attribute=nil
    rms = Referment.
        where(referee_type: "Reference").
        includes(:referee).
        to_a.
        keep_if { |rm| rm.referee.class == DefinitionReference }
    puts "#{rms.count} DefinitionReferences found"
    rms.collect { |rm|
      ref = rm.referee
      puts "Referment ##{rm.id} to DefinitionReference ##{ref.id}:"
      if block_given?
        yield rm
      elsif attribute
        puts "    #{attribute}: #{ref.method(attribute.to_sym).call}"
        nil
      else
        RefermentServices.new(rm).convert_reference
      end
    }
    nil
  end

end
