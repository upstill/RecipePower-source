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
    reports = []
    # Re-establish connection to old references if they didn't convert
    mappings = []
    File.open('references.txt', 'r') { |file|
      while (l = file.gets).present?
        indices = l.split('=>').map(&:to_i)
        puts "#{indices.first}:#{indices.last}"
        mappings[indices.first] = indices.last
      end
    }
    reports << DefinitionPageRef.where(url: nil).collect { |old_referee|
      # Bad url => need to replace
      Referment.where(referee_type: 'PageRef', referee_id: old_referee.id).collect { |rfm|
        refid = mappings[rfm.id]
        new_referee = DefinitionReference.find(refid)
        rfm.referee = new_referee
        rfm.save
        old_referee.destroy
        "Replaced DefinitionPageRef##{old_referee.id} '#{old_referee.url}' with DefinitionReference #{refid} to #{new_referee.url}"
      }
    }
    Referment.where(referee_type: "Reference").each { |rm|
      if rm.referee.class == DefinitionReference
        reports << RefermentServices.new(rm).convert_reference
      end
    }
    puts reports.flatten.compact.sort
    nil
  end

  def convert_reference
    line = ''
    if referment.referee.class == DefinitionReference
      url = referment.referee.url.sub /www\.foodandwine\.com\/chefs\//, 'www.foodandwine.com/contributors/'
      line << "    Converting Reference #{referment.referee_id} by fetching url '#{url}'\n"
      pr = DefinitionPageRef.fetch(url)
      referment.referee = pr
      result = referment.save ? 'successfully' : 'unsuccessfully'
      line << "    Referment ##{referment.id} #{result} converted to DefinitionPageRef ##{pr.id}\n"
      line << "    PageRef #{pr.id} says #{pr.errors.messages}\n" if pr.errors.any?
      line << "    Referment #{referment.id} says #{referment.errors.messages}\n" if referment.errors.any?
    end
    line
  end

  def self.recover_references
    File.open('references.txt', 'w') { |file|
      Referment.where(referee_type: "Reference").each { |rfm|
        file.puts "#{rfm.id}=>#{rfm.referee_id}"
      }
    }
    nil
  end
end