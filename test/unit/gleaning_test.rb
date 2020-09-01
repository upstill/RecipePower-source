require 'test_helper'
class GleaningTest < ActiveSupport::TestCase

  test "read a file into gleaning" do
    pr = PageRef.new url: "http://www.tasteofbeirut.com/persian-cheese-panir/"
    pr.request_attributes :url, :title, :content
    gl = pr.gleaning
    assert_equal [:title, :content],  gl.needed_attributes
    gl.ensure_attributes :url
    refute gl.content_ready
    assert gl.content_needed
    assert gl.title_ready
    refute gl.title_needed
    assert gl.url_ready
    refute gl.url_needed
  end

end