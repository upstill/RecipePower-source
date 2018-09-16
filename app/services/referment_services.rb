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

  # Ensure the existence of a Referment of a particular kind with the given url
  def self.assert kind, url
    def self.bail attribute, err
      rtn = Referment.new
      rtn.errors.add attribute, err
      rtn
    end
    begin
      uri = URI url
    rescue Exception => e
      # Bad URL or path => Post an error in an unsaved record and return
      return bail(:url, 'is not a viable URL')
    end
    if uri.host.match 'recipepower.com'
      # An internal link, presumably to a Referrable entity
      begin
        hsh = Rails.application.routes.recognize_path uri.path
        controller, id = hsh[:controller], hsh[:id].to_i
        model_class = controller.classify.constantize
        model = model_class.find_by id: id
      rescue Exception => e
        # Bad URL or path => Post an error in an unsaved record
        return bail(:url, 'isn\'t anything viable in RecipePower')
      end
      if model.is_a?(Referrable)
        Referment.new(referee: model)
      else
        bail(:referee, 'isn\'t Referrable')
      end
    else
      # An external link
      if pr = PageRef.fetch(url) # URL produces a viable PageRef
        pr.kind = kind
        Referment.new referee: pr
      else
        bail(:url, 'can\'t be read')
      end
    end
  end

end
