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
    expected = '<a id="Some ID" class="oddclass submit" title="Your Tooltip Here" data-href="some/path.json?querytags=no+tags&amp;mode=page" href="javascript:void(0);">My link</a>'
    assert_dom_equal expected, link
  end

  test "Destroy produces JSON request" do
    link1 = link_to_submit  'Destroy', "expression", confirm: 'Are you sure?', method: :delete
    link2 = link_to 'Destroy', "javascript:void(0);", title: 'Your Tooltip Here', data: { href: 'expression.json', confirm: 'Are you sure?' }, method: :delete, class: "submit"
    assert_dom_equal link1, link2
  end

  test "link_to_submit on page is indistinguishable from link_to" do
    link1 = link_to_submit "My link", "some/path", mode: :page, :"some_data" => "Query goes here", class: "oddclass", id: "Some ID"
    link2 = link_to "My link", "javascript:void(0);", title: 'Your Tooltip Here', data: { href: 'some/path.json?mode=page', some_data: "Query goes here" }, class: "oddclass submit", id: "Some ID"
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

    link2 = link_to 'X', 'javascript:void(0);',
                    :method => :delete,
                    :title => 'Your Tooltip Here',
                    :data => {
                        :'confirm-msg' => "Yes, disconnect from provider_name+?",
                        :'wait-msg' => "Hang on while we check with provider_name",
                        :href => "authentication_url.json"
                    },
                    :class => "remove submit"
    assert_dom_equal link1, link2
  end

  test "link_to_submit behaves properly" do
    actual = link_to_submit "My link", "some/path"
    expected = '<a class="submit" title="Your Tooltip Here" data-href="some/path.json" href="javascript:void(0);">My link</a>'
    assert_dom_equal expected, actual

    actual = button_to_submit "My link", "some/path"
    expected = '<a class="btn btn-default submit" title="Your Tooltip Here" data-href="some/path.json" href="javascript:void(0);">My link</a>'
    assert_dom_equal expected, actual

    actual = link_to_submit "My link", "some/path", mode: :partial
    expected = "<a href='javascript:void(0);' title='Your Tooltip Here' data-href='some/path.json?mode=partial' class='submit'>My link</a>"
    assert_dom_equal expected, actual

    actual = link_to_submit "My link", "some/path", class: "linker", method: "delete"
    expected = "<a href='javascript:void(0);' title='Your Tooltip Here' data-href='some/path.json' class='linker submit' data-method='delete' rel='nofollow'>My link</a>"
    assert_dom_equal expected, actual

    actual = link_to_submit "My link", "some/path", class: "linker", method: "post"
    expected = "<a href='javascript:void(0);' title='Your Tooltip Here' data-href='some/path.json' class='linker submit' data-method='post' rel='nofollow'>My link</a>"
    assert_dom_equal expected, actual

    actual = link_to_submit "My link", "some/path", class: "someclass", id: "someid"
    expected = "<a href='javascript:void(0);' title='Your Tooltip Here' data-href='some/path.json' class='someclass submit' id='someid'>My link</a>"
    assert_dom_equal expected, actual

    actual = button_to_submit "My link", "some/path", class: "someclass", id: "someid"
    expected = "<a href='javascript:void(0);' title='Your Tooltip Here' data-href='some/path.json' class='someclass btn btn-default submit' id='someid'>My link</a>"
    assert_dom_equal expected, actual

    actual = link_to_submit "My link", "some/path", mode: :modal, class: "someclass", id: "someid"
    expected = "<a href='javascript:void(0);' title='Your Tooltip Here' data-href='some/path.json?mode=modal' class='someclass submit' id='someid'>My link</a>"
    assert_dom_equal expected, actual

    actual = button_to_submit "My link", "some/path", mode: :partial, class: "someclass", id: "someid"
    expected = "<a href='javascript:void(0);' title='Your Tooltip Here' data-href='some/path.json?mode=partial' class='someclass btn btn-default submit' id='someid'>My link</a>"
    assert_dom_equal expected, actual

    actual = link_to_submit "My link", "some/path", method: "delete", class: "someclass", id: "someid"
    expected = "<a href='javascript:void(0);' title='Your Tooltip Here' data-href='some/path.json' class='someclass submit' data-method='delete' id='someid' rel='nofollow'>My link</a>"
    assert_dom_equal expected, actual

    actual = link_to_submit "My link", "some/path", method: "post", class: "someclass", id: "someid"
    expected = "<a href='javascript:void(0);' title='Your Tooltip Here' data-href='some/path.json' class='someclass submit' data-method='post' id='someid' rel='nofollow'>My link</a>"
    assert_dom_equal expected, actual
  end


end