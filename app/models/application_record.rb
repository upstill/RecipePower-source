class ActiveRecord::Base
  
  # Making (at least) update_attributes happy by declaring responsiveness to mass-assignable attributes
  alias_method :'ar_respond_to?', :'respond_to?'
  def respond_to?(method, include_private = false)
    ar_respond_to?(method, include_private) ||
        ( self.class.respond_to?(:mass_assignable_attributes) &&
            self.class.mass_assignable_attributes.include?(method.to_s.sub(/=$/, '').to_sym) )
  end
end

class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true
end
