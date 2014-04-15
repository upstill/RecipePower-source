class ReferenceServices

  attr_accessor :reference

  delegate :url, :thumbnail, :reference_type, :to => :reference

  def initialize(reference)
    self.reference = reference
  end

  # Convert ALL references to STI specification
  def self.convert_to_sti
    Reference.where(type: "Reference").each do |ref|
      ref.type = ref.typesym.to_s+"Reference"
      ref.save
    end
  end
end