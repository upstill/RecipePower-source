class ImageReferenceServices

  attr_accessor :reference

  delegate :url, :to => :reference # , :reference_type

  def initialize(reference)
    self.reference = reference
  end

  # Assert an image, linking back to a referent
  def self.assert_image_for_referent(uri, tag_or_referent)
      ref = ImageReferenceServices.find_or_initialize uri
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
    Rails.logger.debug report
    ImageReference.where id: extant_ids
  end

  # Compile an array of the entities that use this ImageReference
  def dependents
    (   [Feed, FeedEntry, List, Product, Recipe, PageRef, Referent].collect {|klass| klass.where(picture: @reference).to_a} +
        [Site, User].collect {|klass| klass.where(thumbnail: @reference).to_a} +
        Referment.where(referee: @reference).to_a
    ).flatten
  end

  # Either locate an extant (persisted) ImageReference, or one that is

  # Since the URL is never written once established, this method uniquely handles both
  # data URLs (for images with data only and no URL) and fake URLS (which are left in place for the latter)
  # NB: Implicit in here is the strategy for maintainng the data: since we only fetch reference
  # records by URL when assigning a URL to an entity, we only go off to update the data when
  # the URL is assigned
  def self.find_or_initialize url
    case url
    when /^\d\d\d\d-/
      self.find_by url: url # Fake url previously defined
    when /^data:/
      # Data URL for imagery is acceptable, but it's stored in #thumbdata, with a fake but unique nonsense URL
      self.find_by(thumbdata: url) ||
          begin
            ref = ImageReferenceServices.build url: ImageReference.fake_url
            ref.accept_attribute :thumbdata, url
            ref.status = :good
            ref
          end
    when nil
    when ''
    else # Presumably this is a valid URL
      # Normalize for lookup
      normalized = normalize_url url
      if normalized.blank? # Check for non-empty URL
        ref = ImageReference.new url: normalized # Initialize a record just to report the error
        ref.errors.add :url, "can't be blank"
        ref
      elsif ref = self.lookup(normalized) # Found an existing record on the normalized URL => Success!
        ref
      elsif redirected = test_url(normalized) # Purports to be a url, but doesn't work
        self.lookup(redirected) || self.build(url: redirected)
      else
        ref = ImageReference.new url: normalized # Initialize a record just to report the error
        ref.errors.add :url, "\'#{url}\' doesn't seem to be a working URL. Can you use it as an address in your browser?"
        ref
      end
    end
  end

  private

  # In #find_or_build sometimes we need to find an ImageReference that has been priorly built but not yet persisted.
  # To make these as yet unpersisted image_refs findable, we keep a cache of unpersisted image_refs (the
  # hash @@UNPERSISTED, keyed on the url attribute).

  # Index an ImageReference by URL or URLs, assuming it exists (i.e., no initialization or creation)
  def self.lookup url
    begin
      url = normalize_url url
    rescue
      # If we can't normalize the url, then use the un-normalized version and hope for the best
      return self.where( '"references"."url" ILIKE ?', "#{url}%" )
    end
    url.sub! /^https?:\/\//, ''  # Elide the protocol, if any
    self.find_by( url: 'http://'+url) || self.find_by( url: 'https://'+url)
  end

  # Get the ImageReference for the given key-value pair (either url or thumbdata), including a search among unpersisted records
  def self.find_by keyval
    case keyval.keys.first
    when :url
      self.unpersisted[keyval[:url]]
    when :thumbdata
      v = self.unpersisted.find { |key, value| value.thumbdata == keyval[:thumbdata] }
      v&.values&.first
    end || ImageReference.find_by(keyval)
  end

  def self.unpersisted
    (@@UNPERSISTED ||= {}).keep_if { |url, image_ref| !image_ref.persisted? }
  end

  # Build a new ImageReference and add it to the unpersisted set
  def self.build options = {}
    self.unpersisted[options[:url]] = (image_ref = ImageReference.new url: options[:url])
    # Initialize other attributes
    options.except(:url).each { |attr, val| image_ref.send :"#{attr}=", val }
    image_ref
  end


end
