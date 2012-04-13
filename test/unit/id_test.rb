# encoding: UTF-8
require 'test_helper'
class TagTest < ActiveSupport::TestCase 
    fixtures :tags
    
    # String matches for given set of types
    test "tag matches against set of types" do
        t = Tag.assert_tag("tagtypecheck", tagtype: 1)
        assert_equal t, Tag.strmatch("tagtypecheck", tagtype: [1,2,3]).first
    end
end
