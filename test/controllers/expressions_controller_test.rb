require 'test_helper'

class ExpressionsControllerTest < ActionDispatch::IntegrationTest
  include Warden::Test::Helpers
  Warden.test_mode!
  fixtures :expressions, :users
  setup do
    tagee = users(:thing3)
    login_as(tagee, scope: :user)
    @expression = expressions(:dessert)
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:expressions)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create expression" do
    count_before = Expression.count
    # post '/expressions', expression: @expression.attributes
    post '/expressions',
         format: 'json',
         expression: @expression.attributes.slice( 'tag_id', 'referent_id', 'locale', 'form' )
    count_after = Expression.count
    assert_equal count_before+1, count_after
    expression = Expression.last
    assert_not_equal expression, @expression
    assert_equal expression.attributes.slice('tag_id', 'referent_id', 'locale', 'form'),
                 @expression.attributes.slice('tag_id', 'referent_id', 'locale', 'form')
  end

  test "should update expression" do
    # A commit (submit button title) that includes 'Publish' is the signal to flip Published on
    patch expression_path(@expression), expression: { 'locale' => 2 }
    assert_redirected_to expression_path(assigns(:expression))
    @expression.reload
    assert_equal @expression.localesym, :it
    assert_equal @expression.localename, 'Italian'
    assert_equal @expression.locale, '2'
  end

  test "should show expression" do
    get 'show', id: @expression
    assert_response :success
  end

  test "should get edit" do
    get :edit, id: @expression
    assert_response :success
  end

  test "should destroy expression" do
    assert_difference('Expression.count', -1) do
      delete :destroy, id: @expression
    end

    assert_redirected_to expressions_path
  end
end
