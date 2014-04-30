require 'reference.rb'
class ThumbnailServices
    attr_accessor :thumbnail

    delegate :url, :thumbnail, :reference_type, :to => :thumbnail

    def initialize(thumbnail)
      self.thumbnail = thumbnail
    end

    def self.convert_all_to_references n=-1
      Thumbnail.all[0..n].each { |th|
        self.new(th).convert_to_reference
      }
    end

    def convert_to_reference
      imageref = ImageReference.find_or_initialize @thumbnail.url
      if imageref.id
        # Image Reference with same URL as thumbnail: check that thumbdata matches
        if imageref.thumbdata != @thumbnail.thumbdata
          puts %Q{ImageReference ##{imageref.id} (url #{imageref.url}) doesn't match thumbdata of Thumbnail ##{@thumbnail.id} (url #{@thumbnail.url}). }
        end
      else
        imageref.thumbdata = @thumbnail.thumbdata
        imageref.status = @thumbnail.status
        imageref.save
      end
    end

    def self.test_conversion
      Recipe.all.each do |recipe|
        if recipe.thumbnail.url != recipe.picture.url || recipe.thumbnail.thumbdata != recipe.picture.thumbdata
          debugger
          x=2
        end
      end
    end
end