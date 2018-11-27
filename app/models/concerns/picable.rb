# A picable class has an associated image
module Picable
  require 'image_reference.rb'
  extend ActiveSupport::Concern
  # include Linkable

  module ClassMethods
    def mass_assignable_attributes keys=[]
      [ self.picable_attribute, self.image_reference_name ] + (defined?(super) ? super(keys) : [] )
    end

    def picable picable_attribute, reference_name=:picture, fallback_img_file='NoPictureOnFile.png'
      reference_name = reference_name.to_sym
      picable_attribute = picable_attribute.to_sym
      belongs_to reference_name, class_name: 'ImageReference'

      self.instance_eval do

        # Define singleton getter and setter methods for the URL by using an ImageReference object.
        # Once a URL is in use for an entity of a particular type (Recipe, site, image, etc.), it
        # remains bound to that entity until the entity is destroyed.
        # In particular, this gives a special meaning to url assignment: the URL is 1) checked that it
        #  is unique within the class (actually, type of ImageReference) and then 2) non-destructively assigned
        #  to the object by creating a new ImageReference bound to the object.
        # IT IS AN ERROR TO ASSIGN A URL WHICH IS IN USE BY ANOTHER ENTITY OF THE SAME CLASS.
        define_method "#{picable_attribute}=" do |pu|
          # Since we can't modify references once created, we can only assert a new
          # URL by resort to a new reference
          # Get the existing reference
          #          if options[:as]
          # The reference is to another entity type: we just index by URL and assign the reference association
          ref = pu.blank? ? nil : ImageReference.find_or_initialize(pu)
          self.method(:"#{reference_name}=").call ref
          if self.has_attribute? picable_attribute
            # Set the old url attribute--if it still exists
            super pu
          end
          pu
        end

        define_method(picable_attribute) do
          # This will cause an exception for entities without a corresponding reference
          ((reference = self.method(reference_name).call) && reference.digested_reference) ||
              (super() if self.has_attribute?(picable_attribute)) # In case there's a direct attribute for the link
        end
      end

      self.class_eval do
        define_singleton_method :image_reference_name do
          reference_name
        end
        define_singleton_method :picable_attribute do
          picable_attribute
        end
        define_method :fallback_imgdata do
          fallback_img_file
        end
        alias_method :imglink, picable_attribute
      end
    end
  end

  def self.included(base)
    base.extend ClassMethods
  end

  public

  def picable_attribute
    self.class.picable_attribute
  end

  def picref
    @picref ||= self.method(self.class.image_reference_name).call
  end

  # Return the image for the entity, either as a URL or a data specifier
  # The image may have an associated thumbnail, but it doesn't count unless
  # the thumbnail reflects the image's current private_picurl
  def imgdata fallback_to_url=true
    if picref && (href = picref.imgdata || (fallback_to_url && picref.url)).present?
      href
    end
  end

  # Ignore the thumbnail and return a url
  def imgurl
    picref.imgurl if picref
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
