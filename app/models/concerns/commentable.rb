module Commentable
  extend ActiveSupport::Concern

  module ClassMethods

    def mass_assignable_attributes keys=[]
      [ self.comment_attribute_name ].compact + (defined?(super) ? super : [])
    end

    def comment_attribute_name
      @comment_attribute_name
    end

    def commentable attr_name=:comment
      # attr_accessible attr_name
      @comment_attribute_name = attr_name
    end

  end

end
