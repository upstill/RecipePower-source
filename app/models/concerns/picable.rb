# A picable class has an associated image
module Picable
  extend ActiveSupport::Concern
  include Linkable

  module ClassMethods

    def picable attribute, reference_name=:picture
      linkable attribute, reference_name, :as => "ImageReference"
      self.class_eval do
        define_singleton_method :image_reference_name do
          reference_name
        end
        define_singleton_method :picable_attribute do
          attribute
        end
      end
    end
  end

  public

  def picref
    @picref ||= self.method(self.class.image_reference_name).call
  end

  def picrefid
    picref.id if picref
  end

  # Return the thumbnail data for the entity
  def picdata
    picref.thumbdata if picref
  end

  # Return the image for the entity as a url
  # NB: This isn't necessarily a valid URL: Conventionally, if an image comes
  # in as a data URL, the data is moved into thumbdata and the url becomes a
  # unique string not otherwise useful.
  def picuri
    picref.url if picref
  end

  # Return the image for the entity, either as a URL or a data specifier
  # The image may have an associated thumbnail, but it doesn't count unless
  # the thumbnail reflects the image's current private_picurl
  def imgdata fallback_to_card=false
    if picref
      (href = picref.imgdata) && (return href)
      "/assets/BadPicURL.png" if fallback_to_card
    else
      "/assets/NoPictureOnFile.png" if fallback_to_card
    end # Default
  end

  # One picable is being merged into another => transfer image
  def absorb other
    # Act only if there's not already an image in the absorber
    unless picref
      if otherpic = other.method(other.class.image_reference_name).call
        self.method(:"#{self.class.image_reference_name}=").call otherpic
      end
    end
    super if defined? super
  end

end
