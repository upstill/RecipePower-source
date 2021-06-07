require 'test_helper'
class GleaningTest < ActiveSupport::TestCase

  def setup
    super
  end

  test "read a file into gleaning" do
    pr = PageRef.new url: "http://www.tasteofbeirut.com/persian-cheese-panir/"
    pr.request_attributes [ :title, :content]
    gl = pr.gleaning
    assert_equal [:picurl, :title, :content].sort,  gl.needed_attributes.sort
    gl.ensure_attributes [ :url ]
    refute gl.content_ready  # Not extracted
    refute gl.content_needed # Gave up
    assert gl.title_ready    # Successfully extracted...
    refute gl.title_needed   # ...so no longer needed
    assert gl.url_ready
    refute gl.url_needed
  end

end
