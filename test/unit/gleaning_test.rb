require 'test_helper'
class GleaningTest < ActiveSupport::TestCase

  test "read a file into gleaning" do
    pr = PageRef.new url: "http://www.tasteofbeirut.com/persian-cheese-panir/"
    pr.request_attributes :title, :content
    gl = pr.gleaning
    assert_equal [:url, :title, :content],  gl.needed_attributes
    gl.ensure_attributes :url
    refute gl.content_ready  # Not extracted
    refute gl.content_needed # Gave up
    assert gl.title_ready    # Successfully extracted...
    refute gl.title_needed   # ...so no longer needed
    assert gl.url_ready
    refute gl.url_needed
  end

end