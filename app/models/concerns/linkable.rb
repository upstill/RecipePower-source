module Linkable
  extend ActiveSupport::Concern

  included do
    has_one :link, :as => :entity
  end

end