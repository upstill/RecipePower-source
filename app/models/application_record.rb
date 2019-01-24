class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true
  def respond_to?(method, include_private = false)
    super ||
        ( self.class.respond_to?(:mass_assignable_attributes) &&
            self.class.mass_assignable_attributes.include?(method.to_s.sub(/=$/, '').to_sym) )
  end
end
