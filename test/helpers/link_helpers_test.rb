require 'test_helper'

class LinkHelpersTest < ActionView::TestCase
  include ApplicationHelper
  include LinkHelper

  def setup
    @big_bad_options = {
        query: { querytags: "no tags"},
        id: "Some ID",
        class: "oddclass",
        remote: true,
        pre: "Preloaded data"
    }
  end

  test "link_to_page behaves properly" do
    link = link_to_submit "My link", "some/path", mode: :page, query: { querytags: "no tags"}, class: "oddclass", id: "Some ID"
    expected = "<a href='some/path?querytags=no+tags' class='oddclass' id='Some ID' >My link</a>"
    assert_dom_equal expected, link
  end

  test "Destroy produces JSON request" do
    link1 = link_to_submit  'Destroy', "expression", confirm: 'Are you sure?', method: :delete
    link2 = link_to 'Destroy', "expression.json", data: { confirm: 'Are you sure?' }, method: :delete, class: "submit"
    assert_dom_equal link1, link2
  end

  test "link_to_submit on page is indistinguishable from link_to" do
    link1 = link_to_submit "My link", "some/path", mode: :page, :"some_data" => "Query goes here", class: "oddclass", id: "Some ID"
    link2 = link_to "My link", "some/path", data: { some_data: "Query goes here" }, class: "oddclass", id: "Some ID"
    assert_dom_equal link1, link2

    link1 = link_to_submit("Refresh Masonry", "#", onclick: "RP.collection.justify();", mode: :page)
    link2 = link_to("Refresh Masonry", "#", onclick: "RP.collection.justify();")
    assert_dom_equal link1, link2
  end

  test "standard data options get folded into data" do

    link1 = link_to_submit "X", "authentication_url",
                           :method => :delete,
                           :"data-confirm-msg" => "Yes, disconnect from provider_name+?",
                           :"data-wait-msg" => "Hang on while we check with provider_name",
                           :class => "remove"
    link2 = link_to_submit "X", "authentication_url",
                           :method => :delete,
                           :"confirm-msg" => "Yes, disconnect from provider_name+?",
                           :"wait-msg" => "Hang on while we check with provider_name",
                           :class => "remove"
    assert_dom_equal link1, link2

    link2 = link_to "X", "authentication_url.json",
                    :method => :delete,
                    :"data-confirm-msg" => "Yes, disconnect from provider_name+?",
                    :"data-wait-msg" => "Hang on while we check with provider_name",
                    :class => "remove submit"
    assert_dom_equal link1, link2
  end

  test "link_to_submit behaves properly" do
    actual = link_to_submit "My link", "some/path"
    expected = "<a href='some/path.json' class='submit'>My link</a>"
    assert_dom_equal expected, actual

    actual = button_to_submit "My link", "some/path"
    expected = "<a href='some/path.json' class='btn btn-default btn-xs submit'>My link</a>"
    assert_dom_equal expected, actual

    actual = link_to_submit "My link", "some/path", mode: :partial
    expected = "<a href='some/path.json?mode=partial' class='submit'>My link</a>"
    assert_dom_equal expected, actual

    actual = link_to_submit "My link", "some/path", class: "linker", method: "delete"
    expected = "<a href='some/path.json' class='linker submit' data-method='delete' rel='nofollow'>My link</a>"
    assert_dom_equal expected, actual

    actual = link_to_submit "My link", "some/path", class: "linker", method: "post"
    expected = "<a href='some/path.json' class='linker submit' data-method='post' rel='nofollow'>My link</a>"
    assert_dom_equal expected, actual

    actual = link_to_submit "My link", "some/path", class: "someclass", id: "someid"
    expected = "<a href='some/path.json' class='someclass submit' id='someid'>My link</a>"
    assert_dom_equal expected, actual

    actual = button_to_submit "My link", "some/path", class: "someclass", id: "someid"
    expected = "<a href='some/path.json' class='someclass btn btn-default btn-xs submit' id='someid'>My link</a>"
    assert_dom_equal expected, actual

    actual = link_to_submit "My link", "some/path", mode: :modal, class: "someclass", id: "someid"
    expected = "<a href='some/path.json?mode=modal' class='someclass submit' id='someid'>My link</a>"
    assert_dom_equal expected, actual

    actual = button_to_submit "My link", "some/path", mode: :partial, class: "someclass", id: "someid"
    expected = "<a href='some/path.json?mode=partial' class='someclass btn btn-default btn-xs submit' id='someid'>My link</a>"
    assert_dom_equal expected, actual

    actual = link_to_submit "My link", "some/path", class: "linker", method: "delete", class: "someclass", id: "someid"
    expected = "<a href='some/path.json' class='someclass submit' data-method='delete' id='someid' rel='nofollow'>My link</a>"
    assert_dom_equal expected, actual

    actual = link_to_submit "My link", "some/path", class: "linker", method: "post", class: "someclass", id: "someid"
    expected = "<a href='some/path.json' class='someclass submit' data-method='post' id='someid' rel='nofollow'>My link</a>"
    assert_dom_equal expected, actual
  end


end