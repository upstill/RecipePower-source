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

  def self.convert_references
    Referment.where(referee_type: "Reference").each { |rm|
      RefermentServices.new(rm).convert_reference if rm.referee.class == DefinitionReference
    }
    nil
  end

  def convert_reference
    if referment.referee.class == DefinitionReference
      url = referment.referee.url.sub /www\.foodandwine\.com\/chefs\//, 'www.foodandwine.com/contributors/'
      puts "    Converting Reference #{referment.referee_id} by fetching url '#{url}'"
      if pr = DefinitionPageRef.fetch(url)
        referment.referee = pr
        result = referment.save ? 'successfully' : 'unsuccessfully'
        puts("    Referment ##{referment.id} #{result} converted to DefinitionPageRef ##{pr.id}")
        puts("    PageRef #{pr.id} says #{pr.errors.messages}") if pr.errors.any?
        puts("    Referment #{referment.id} says #{referment.errors.messages}") if referment.errors.any?
      end
    end
  end
end