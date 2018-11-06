# encoding: UTF-8
require 'test_helper'
require 'warden_test_helper'

class ListsControllerTest < ActionController::TestCase
  fixtures :lists, :users

  setup do
    # tagee = users(:thing3)
    # login_as(tagee, scope: :user)
    @list = lists :dessert
  end

  test "should create list" do
    count_before = List.count
    # post '/lists', list: @list.attributes
    post '/lists',
         format: 'json',
         list: @list.attributes.slice( 'tag_id', 'referent_id', 'locale', 'form' )
    count_after = List.count
    assert_equal count_before+1, count_after
    list = List.last
    assert_not_equal list, @list
    assert_equal list.attributes.slice('tag_id', 'referent_id', 'locale', 'form'),
                 @list.attributes.slice('tag_id', 'referent_id', 'locale', 'form')
  end

  test "should update list" do
    # A commit (submit button title) that includes 'Publish' is the signal to flip Published on
    patch list_path(@list), list: { 'locale' => 2 }
    assert_redirected_to list_path(assigns(:list))
    @list.reload
    assert_equal @list.localesym, :it
    assert_equal @list.localename, 'Italian'
    assert_equal @list.locale, '2'
  end

  test "should collect querytags" do
    get :index, querytags: "yeltsin"
    assert_response :success
    assert_equal "yeltsin", @controller.querytags.first.name
    assert_equal "yeltsin", session[:querytags]["-1"]

    get :index, querytags: "-1"
    assert_equal "yeltsin", @controller.querytags.first.name
    assert_equal "yeltsin", session[:querytags]["-1"]
  end
end