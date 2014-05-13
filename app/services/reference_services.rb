class ReferenceServices

  attr_accessor :reference

  delegate :url, :thumbdata, :to => :reference # , :reference_type

  def initialize(reference)
    self.reference = reference
  end

  # Convert ALL references to STI specification
  def self.convert_to_sti n=-1
    set = Reference.where(type: "Reference")[0..n].each do |ref|
      ref.type = ref.typesym.to_s+"Reference"
      ref.save # ref.ping
    end
  end

end