require 'test_helper'
class MercuryResultTest < ActiveSupport::TestCase

  test "read a file into MercuryResult" do
    mr = MercuryResult.new
    mr.accept_attribute :url, "http://www.tasteofbeirut.com/persian-cheese-panir/"
    assert mr.url_ready
    refute mr.url_needed

    mr.ensure_attributes
    assert_empty mr.needed_attributes

  end

end