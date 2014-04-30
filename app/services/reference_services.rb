class ReferenceServices

  attr_accessor :reference

  delegate :url, :thumbdata, :reference_type, :to => :reference

  def initialize(reference)
    self.reference = reference
  end

  # Convert ALL references to STI specification
  def self.convert_to_sti n=-1
    set = Reference.where(type: "Reference")[0..n].each do |ref|
      ref.type = ref.typesym.to_s+"Reference"
      ref.ping
    end
  end

end