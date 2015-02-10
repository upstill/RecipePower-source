require 'test_helper'

class SuggestionTest < ActiveSupport::TestCase
  fixtures :feeds
  fixtures :users
  fixtures :referents
  fixtures :tags
  fixtures :recipes

  test "can initialize a suggestion" do
    user = users(:thing1)
    viewer = users(:thing2)
    session_id = "OXDH#(INRKES"
    sug1 = UserSuggestion.find_or_make(user, viewer, "1, 2", session_id)
    sug1.reload
    assert_equal UserSuggestion, sug1.class
    assert_equal sug1.base, user
    assert_equal sug1.viewer, viewer
    assert_equal "1, 2", sug1.filter
  end
end
