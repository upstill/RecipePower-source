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
        end
      end
    end

    public

    # Return the image for the entity, either as a URL or a data specifier
    # The image may have an associated thumbnail, but it doesn't count unless
    # the thumbnail reflects the image's current private_picurl
    def picdata data_only = false
      if imageref = self.method(self.class.image_reference_name).call
        imageref.thumbdata || imageref.url
      end
    end

  end
