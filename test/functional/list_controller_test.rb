require File.dirname(__FILE__) + '/../test_helper'

class ListControllerTest < ActionController::TestCase

  def hackytags_saved_and_restored
    name = "yeltsin"
    rp = ResponseServices.new( { tagstxt: name }, {}, nil )
    assert_equal name, rp.tags.first.name
    id = rp.tags.first.id

    rp = ResponseServices.new( {:tagstxt => id.to_s}, {}, nil )
    assert_equal name, rp.tags.first.name
  end

end