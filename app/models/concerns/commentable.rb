module Commentable
  extend ActiveSupport::Concern

  module ClassMethods

    def commentable attr_name=:comment
      attr_accessible attr_name

    end

  end

end
