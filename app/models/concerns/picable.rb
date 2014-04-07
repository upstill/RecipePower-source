# A picable class has an associated image
module Picable
    extend ActiveSupport::Concern

    included do
      belongs_to :thumbnail
    end

  end