class ThumbnailServices
    attr_accessor :thumbnail

    delegate :url, :thumbnail, :reference_type, :to => :thumbnail

    def initialize(thumbnail)
      self.thumbnail = thumbnail
    end

    def self.convert_all_to_reference

    end

    def convert_to_reference
      debugger
      imageref = Reference.find_or_initialize url: @thumbnail.url, type: "ImageReference"
      if imageref.id
        # Image Reference with same URL as thumbnail: check that thumbdata matches
        if imageref.thumbdata != @thumbnail.thumbdata
          puts %Q{ImageReference ##{imagref.id} (url #{imageref.url})doesn't match thumbdata of Thumbnail ##{@thumbnail.thumbdata}}
        end
      else
        imageref.thumbdata = @thumbnail.thumbdata
        imageref.status = @thumbnail.status
        imageref.save
      end
    end
end