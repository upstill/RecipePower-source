# A picable class has an associated image
module Picable
    extend ActiveSupport::Concern

    module ClassMethods

      def picable(attribute, sample=nil)
        @pic_attrib_name = attribute
        @sample_name = sample
      end

      def pic_attrib_name
        @pic_attrib_name
      end

    end

    def self.included(base)
      base.extend(ClassMethods)
    end

    attr_accessible :thumbnail

    # An image reference has a local thumbnail for cached image data
    belongs_to :thumbnail, :autosave => true

    # Before saving the recipe, take the chance to generate a thumbnail (in background)
    before_save :check_thumbnail

    def picurl
      self.read_attribute self.class.pic_attrib_name
    end

    def picurl=(url)
      self.write_attribute self.class.pic_attrib_name, url
    end

    private

    # Confirm that the thumbnail accurately reflects the recipe's image
    def check_thumbnail
      self.picurl = nil if self.picurl.blank? || (self.picurl == "/assets/NoPictureOnFile.png")
      if self.picurl.nil? || self.picurl =~ /^data:/
        # Shouldn't have a thumbnail
        self.thumbnail = nil
      elsif picurl_changed? || !thumbnail
        # Make sure we've got the right thumbnail
        self.thumbnail = Thumbnail.acquire( url, picurl )
      end
      true
    end

    public

    # Return the image for the recipe, either as a URL or a data specifier
    # The image may have an associated thumbnail, but it doesn't count unless
    # the thumbnail reflects the image's current picurl
    def picdata
      case
        when !picurl || (picurl =~ /^data:/)
          picurl
        when thumbnail && thumbnail.thumbdata
          thumbnail.thumbdata
        else
          picurl unless picurl.blank?
      end
    end

  end