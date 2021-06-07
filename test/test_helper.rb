ENV['RAILS_ENV'] ||= 'test'
require File.expand_path('../../config/environment', __FILE__)
require 'rails/test_help'

class ActiveSupport::TestCase
  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  include FactoryBot::Syntax::Methods
  fixtures :all

  # Add more helper methods to be used by all tests here...
  #
  # Confirm that the values in an attributes hash match those in the object
  def confirm_attributes valhash, object
    valhash.each do |key, val|
      assert_equal val, object.send(key.to_sym)
    end
  end

  def setup
    ImageReferenceServices.clear_unpersisted
    SiteServices.clear_unpersisted
  end
end
