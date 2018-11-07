# encoding: UTF-8
require 'test_helper'
# require 'warden_test_helper'

class ListsControllerTest < ActionDispatch::IntegrationTest
  include Warden::Test::Helpers
  Warden.test_mode!
  fixtures :lists, :users, :tags

  setup do
    tagee = users(:thing3)
    login_as(tagee, scope: :user)
    # @list = FactoryBot.create(:list)
    @list_params = {
        # collectible_user_id: 3, # Not assignable, but taken from current_user
        collectible_comment: 'this would be a comment',
        name: "Some other kind of list",
        # name_tag_id: 15, # Implicit from name assignment
        description: 'compiling something',
        notes: 'notes would go here',
        availability: 2,
        included_tag_tokens: "11",
        pullin: 1,
        # tagging_user_id: 3, # Not assignable, but taken from current_user
        editable_dish_tag_tokens: "4",
        editable_ingredient_tag_tokens: "3",
        tagging_list_tokens: "1"
        }
  end

  test "should create list" do
    count_before = List.count
    # post '/lists', list: @list.attributes
    post create_list_path, format: 'json', list: @list_params

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