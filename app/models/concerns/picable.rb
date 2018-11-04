# A picable class has an associated image
module Picable
  require 'reference.rb'
  extend ActiveSupport::Concern
  # include Linkable

  module ClassMethods

    def picable picable_attribute, reference_name=:picture, fallback_img_file='NoPictureOnFile.png'
      # linkable picable_attribute, reference_name, :as => 'ImageReference' # 'Reference' #
      reference_name = reference_name.to_sym
      picable_attribute = picable_attribute.to_sym
      ref_type = 'ImageReference'
      # attr_accessible picable_attribute, reference_name
      belongs_to reference_name, class_name: ref_type

      self.instance_eval do

        # Define singleton getter and setter methods for the URL by using a Reference object.
        # Once a URL is in use for an entity of a particular type (Recipe, site, image, etc.), it
        # remains bound to that entity until the entity is destroyed.
        # In particular, this gives a special meaning to url assignment: the URL is 1) checked that it
        #  is unique within the class (actually, type of Reference) and then 2) non-destructively assigned
        #  to the object by creating a new Reference bound to the object.
        # IT IS AN ERROR TO ASSIGN A URL WHICH IS IN USE BY ANOTHER ENTITY OF THE SAME CLASS.
        define_method "#{picable_attribute}=" do |pu|
          # Since we can't modify references once created, we can only assert a new
          # URL by resort to a new reference
          # Get the existing reference
          #          if options[:as]
          # The reference is to another entity type: we just index by URL and assign the reference association
          ref = pu.blank? ? nil : ref_type.constantize.find_or_initialize(pu).first
          self.method(:"#{reference_name}=").call ref
          # elsif pu.blank?
          #   self.errors.add(picable_attribute, 'can\'t be blank')
          # else
          #   # Create a new reference (or references, if there's a redirect involved) as necessary
          #   refs = ref_type.constantize.find_or_initialize(pu)
          #   # Give me the new references
          #   self.method(:"#{reference_name}=").call refs.first
          #   # self.method(:"#{reference_name_pl}=").call refs
          # end
          if self.has_attribute? picable_attribute
            # Set the old url attribute--if it still exists
            super pu
          end
          pu
        end

        define_method(picable_attribute) do
          # This will cause an exception for entities without a corresponding reference
          ((reference = self.method(reference_name).call) && reference.digested_reference) ||
              (super() if self.has_attribute?(picable_attribute))
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
        # ImageReference.register_client self, reference_name
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

  # Return the image for the entity as a url
  # NB: This isn't necessarily a valid URL: Conventionally, if an image comes
  # in as a data URL, the data is moved into thumbdata and the url becomes a
  # unique string not otherwise useful.
  def picuri
    picref.url if picref
  end

=begin
  def picuri_problem
    picref && !picref.usable_url
  end
=end

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
