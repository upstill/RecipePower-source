# A picable class has an associated image
module Picable
    extend ActiveSupport::Concern

    module ClassMethods

      def picable(attribute, home)
        @pic_attrib_name = attribute
        @home_attrib_name = home
        attr_accessible attribute
      end

      def pic_attrib_name
        @pic_attrib_name
      end

      def home_attrib_name
        @home_attrib_name
      end
    end

    included do
      attr_accessible :thumbnail

      # An image reference has a local thumbnail for cached image data
      belongs_to :thumbnail, :autosave => true

      # Before saving the recipe, take the chance to generate a thumbnail (in background)
      before_save :check_thumbnail
    end

    protected

    def private_picurl
      self.read_attribute self.class.pic_attrib_name
    end

    def private_homeurl
      self.read_attribute self.class.home_attrib_name
    end

    def private_picurl=(url)
      self.attributes = { self.class.pic_attrib_name => url }
      # self.write_attribute self.class.pic_attrib_name, url
    end

    def private_picurl_changed?
      changed_attributes.key? self.class.pic_attrib_name.to_s
    end

    # Confirm that the thumbnail accurately reflects the recipe's image
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

    public

    # Return the image for the recipe, either as a URL or a data specifier
    # The image may have an associated thumbnail, but it doesn't count unless
    # the thumbnail reflects the image's current private_picurl
    def picdata
      case
        when !private_picurl || (private_picurl =~ /^data:/)
          private_picurl
        when thumbnail && thumbnail.thumbdata
          thumbnail.thumbdata
        else
          private_picurl unless private_picurl.blank?
      end
    end

  end