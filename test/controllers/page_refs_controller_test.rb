require 'test_helper'

class PageRefsControllerTest < ActionDispatch::IntegrationTest
  include Warden::Test::Helpers
  Warden.test_mode!
  fixtures :page_refs, :users
  setup do
    login_as users(:thing3), scope: :user
    @page_ref = page_refs(:goodpr)
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:page_refs)
  end

  test "should get new" do
    get new_page_ref_path, format: 'json'
    assert_response :success
  end

  test "should create page_ref" do
    count_before = PageRef.count
    post '/page_refs', page_ref: { url: 'http://www.example.com', kind: 'article' }
    page_ref = PageRef.last
    count_after = PageRef.count
    assert_equal count_before+1, count_after
    assert_equal 'http://www.example.com', page_ref.url
    assert page_ref.article?
  end

  test "should update page_ref" do
    post '/page_refs', page_ref: { url: 'http://www.example.com', kind: 'article' }
    pr = PageRef.new 'date_published' => Time.now
    pr_attributes = { 'title' => 'Arbitrary Title',
                      'content' => 'Most abbreviated content',
                      'date_published' => pr.date_published }
    page_ref = PageRef.last
    login_as users(:thing3), scope: :user
    patch page_ref_path(page_ref), format: 'json', page_ref: pr_attributes
    page_ref.reload
    assert_equal pr_attributes['title'], page_ref.title
    assert_equal pr_attributes['content'], page_ref.content
    assert_equal pr.date_published.inspect, page_ref.date_published.inspect
  end

  test "should show page_ref" do
    get 'show', id: @page_ref
    assert_response :success
  end

  test "should get edit" do
    get :edit, id: @page_ref
    assert_response :success
  end

  test "should destroy page_ref" do
    assert_difference('PageRef.count', -1) do
      delete :destroy, id: @page_ref
    end

    assert_redirected_to page_refs_path
  end
end
