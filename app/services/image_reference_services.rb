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

  # Get a scope for ImageReferences that are not referred to by any other entity
  def self.orphans
    extant_ids = ImageReference.all.pluck :id
    report = []
    report << "#{extant_ids.count} ImageReference ids to start"
    [Feed, FeedEntry, List, Product, Recipe, PageRef, Referent].each do |klass|
      extant_ids -= klass.all.pluck :picture_id
      report << "#{extant_ids.count} ids after #{klass.to_s}"
    end
    [Site, User].each do |klass|
      extant_ids -= klass.all.pluck :thumbnail_id
      report << "#{extant_ids.count} ids after #{klass.to_s}"
    end
    extant_ids -= Referment.where(referee_type: 'ImageReference').pluck :referee_id
    report << "#{extant_ids.count} ids after Referments"
    puts report
    ImageReference.where id: extant_ids
  end

  # Compile an array of the entities that use this ImageReference
  def dependents
    (   [Feed, FeedEntry, List, Product, Recipe, PageRef, Referent].collect {|klass| klass.where(picture: @reference).to_a} +
        [Site, User].collect {|klass| klass.where(thumbnail: @reference).to_a} +
        Referment.where(referee: @reference).to_a
    ).flatten
  end

end
