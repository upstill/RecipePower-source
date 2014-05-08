# A picable class has an associated image
module Picable
    extend ActiveSupport::Concern
    include Linkable

    module ClassMethods

      def picable attribute, reference_name=:picture
        linkable attribute, reference_name, :as => "ImageReference"
        self.class_eval do
          define_singleton_method :pic_attribute_name do
            attribute
          end
          define_singleton_method :image_reference_name do
            reference_name
          end
        end
      end
    end

=begin
    included do
      attr_accessible :thumbnail

      # An image reference has a local thumbnail for cached image data
      belongs_to :thumbnail, :autosave => true

      # Before saving the recipe, take the chance to generate a thumbnail (in background)
      # before_save :check_thumbnail
    end
=end

    protected

    def private_picurl
      self.method(self.class.pic_attribute_name).call
    end

    def private_homeurl
      self.read_attribute self.class.url_attribute_name if self.respond_to?(:url_attribute_name) && self.class.url_attribute_name
    end

    def private_picurl=(url)
      self.attributes = { self.class.pic_attribute_name => url }
      # self.write_attribute self.class.pic_attribute_name, url
    end

    def private_picurl_changed?
      changed_attributes.key? self.class.pic_attribute_name.to_s
    end

    # Confirm that the thumbnail accurately reflects the recipe's image
=begin
    def check_thumbnail
      self.private_picurl = nil if self.private_picurl.blank? || (self.private_picurl == "/assets/NoPictureOnFile.png")
      if self.private_picurl.nil? || self.private_picurl =~ /^data:/
        # Shouldn't have a thumbnail
        self.thumbnail = nil
      elsif private_picurl_changed? || !thumbnail
        # Make sure we've got the right thumbnail
        self.thumbnail = Thumbnail.acquire( private_homeurl, private_picurl )
      end
      true
    end
=end

    public

    # Return the image for the entity, either as a URL or a data specifier
    # The image may have an associated thumbnail, but it doesn't count unless
    # the thumbnail reflects the image's current private_picurl
    def picdata
      imageref = self.method(self.class.image_reference_name).call
      (imageref && imageref.thumbdata) || private_picurl
    end

  end
