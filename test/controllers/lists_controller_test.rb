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
        collectible_user_id: 3, # Not assignable, but taken from current_user
        collectible_comment: 'this would be a comment',
        owner_id: users(:thing3).id,
        name: "Some other kind of list",
        # name_tag_id: 15, # Implicit from name assignment
        description: 'compiling something',
        notes: 'notes would go here',
        availability: 2,
        included_tag_tokens: "11",
        pullin: 1,
        tagging_user_id: 3,
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
    assert_equal list.owner, users(:thing3)
    assert_equal @list_params[:name], list.name
    assert_equal tags(:jal3), list.included_tags.first
    assert_equal @list_params[:collectible_comment], list.rcprefs.first.comment
    assert_equal 1, list.included_tags.count
    assert list.pullin
    %w{ availability description notes  }.each { |attrib|
      assert_equal @list_params[attrib.to_sym],
                   list.attributes[attrib]
    }
  end

  test "should update list" do
    list = lists(:for_testing)
    patch list_path(list), format: 'json', list: @list_params
    list.reload
    assert_equal list.owner, users(:thing3)
    assert_equal @list_params[:name], list.name
    assert_equal tags(:jal3), list.included_tags.first
    assert_equal @list_params[:collectible_comment], list.rcprefs.first.comment
    assert_equal 1, list.included_tags.count
    assert list.pullin
    %w{ availability description notes  }.each { |attrib|
      assert_equal @list_params[attrib.to_sym],
                   list.attributes[attrib]
    }
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