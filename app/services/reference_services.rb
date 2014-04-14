class ReferenceServices

  attr_accessor :reference

  delegate :url, :thumbnail, :reference_type, :to => :reference

  def initialize(reference)
    self.reference = reference
  end

  # Make ALL references polymorphic
  def self.make_polymorphic
    self.all.each do |ref|
      ref.type = ref.typesym.to_s+"Reference"
      ref.save
    end
  end

  # Convert a reference from the flat form to the polymorphic form
  def make_polymorphic
    @reference.type = @reference.typesym.to_s+"Reference"
    @reference.save
  end
end