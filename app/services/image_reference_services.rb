class ImageReferenceServices

  attr_accessor :reference

  delegate :url, :to => :reference # , :reference_type

  def initialize(reference)
    self.reference = reference
  end

  # Assert an image, linking back to a referent
  def self.assert_image_for_referent(uri, tag_or_referent)
      ref = ImageReference.find_or_initialize uri
      if ref.errors.empty?
          rft =
              case tag_or_referent
                  when Tag
                      Referent.express tag_or_referent
                  else
                      tag_or_referent
              end
          if rft
            ref.referents << rft unless ref.referents.exists?(id: rft.id)
            ref.save
          end
      end
      ref
  end

end
