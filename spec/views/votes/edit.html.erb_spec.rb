require 'spec_helper'

describe "votes/edit" do
  before(:each) do
    @vote = assign(:vote, stub_model(Vote,
      :user_id => 1,
      :entity_type => "MyString",
      :entity_id => 1,
      :up => false
    ))
  end

  it "renders the edit vote form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form[action=?][method=?]", vote_path(@vote), "post" do
      assert_select "input#vote_user_id[name=?]", "vote[user_id]"
      assert_select "input#vote_entity_type[name=?]", "vote[entity_type]"
      assert_select "input#vote_entity_id[name=?]", "vote[entity_id]"
      assert_select "input#vote_up[name=?]", "vote[up]"
    end
  end
end
