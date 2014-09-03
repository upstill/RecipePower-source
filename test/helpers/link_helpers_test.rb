require 'test_helper'

class LinkHelpersTest < ActionView::TestCase
  include ApplicationHelper

  def setup
    @big_bad_options = {
        query: { querytags: "no tags"},
        id: "Some ID",
        class: "oddclass",
        remote: true,
        pre: "Preloaded data"
    }
  end

  test "options should get sorted" do
    options = fix_options_for_link @big_bad_options
    refute options[:pre]
    assert_equal "Preloaded data", options[:data][:pre]
    assert_equal "Some ID", options[:id]

    @big_bad_options[:data] = { per: "More data" }
    options = fix_options_for_link @big_bad_options
    assert_equal "More data", options[:data][:per]
    assert_equal "Preloaded data", options[:data][:pre]

    @big_bad_options.delete :pre
    options = fix_options_for_link @big_bad_options
    assert_equal "More data", options[:data][:per]
  end

  test "query gets integrated" do
    qpath = fix_path_for_query "users", @big_bad_options.delete(:query)
    assert_equal "users?querytags=no+tags", URI.unescape(qpath)
  end

  test "null query doesn't affect path" do
    assert_equal "silly path", fix_path_for_query("silly path")
    assert_equal "silly path", fix_path_for_query("silly path", nil)
  end

  test "link_to_page behaves properly" do
    link = link_to_page "My link", "some/path", @big_bad_options
    expected = "<a href='some/path?querytags=no+tags' class='oddclass' id='Some ID' data-remote='true' data-pre='Preloaded data'>My link</a>"
    assert_dom_equal expected, link
  end

  test "link_to_nowhere behaves properly" do
    link = link_to_nowhere "My link", @big_bad_options
    expected = "<a href='#' class='oddclass' id='Some ID' data-remote='true' data-pre='Preloaded data'>My link</a>"
    assert_dom_equal expected, link
  end

  test "link_to_modal behaves properly" do
    link = link_to_modal "My link", "some/path", @big_bad_options
    expected = "<a href='some/path?querytags=no+tags&amp;modal=true' class='submit oddclass' id='Some ID' data-pre='Preloaded data'>My link</a>"
    assert_dom_equal expected, link
  end

  test "button_link behaves properly" do
    link = button_link "My link", "some/path", :submit, "default", "xs", @big_bad_options
    expected = "<a href='some/path?querytags=no+tags&amp;partial=true' class='submit btn btn-default btn-xs oddclass' id='Some ID' data-pre='Preloaded data'>My link</a>"
    assert_dom_equal expected, link

    link = button_link "My link", "some/path", :submit, "default", @big_bad_options
    expected = "<a href='some/path?querytags=no+tags&amp;partial=true' class='submit btn btn-default btn-xs oddclass' id='Some ID' data-pre='Preloaded data'>My link</a>"
    assert_dom_equal expected, link

    link = button_link "My link", "some/path", :submit, @big_bad_options
    expected = "<a href='some/path?querytags=no+tags&amp;partial=true' class='submit btn btn-default btn-xs oddclass' id='Some ID' data-pre='Preloaded data'>My link</a>"
    assert_dom_equal expected, link

    link = button_link "My link", "some/path", @big_bad_options
    expected = "<a href='some/path?querytags=no+tags&amp;partial=true' class='submit btn btn-default btn-xs oddclass' id='Some ID' data-pre='Preloaded data'>My link</a>"
    assert_dom_equal expected, link
  end

end