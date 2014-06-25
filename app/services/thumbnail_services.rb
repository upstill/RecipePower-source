require 'reference.rb'
class ThumbnailServices
    attr_accessor :thumbnail

    delegate :url, :thumbnail, :reference_type, :to => :thumbnail

    def initialize(thumbnail)
      self.thumbnail = thumbnail
    end
end
