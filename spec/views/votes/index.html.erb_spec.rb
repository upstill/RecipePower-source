require 'spec_helper'

describe "votes/index" do
  before(:each) do
    assign(:votes, [
      stub_model(Vote,
        :user_id => 1,
        :entity_type => "Entity Type",
        :entity_id => 2,
        :up => false
      ),
      stub_model(Vote,
        :user_id => 1,
        :entity_type => "Entity Type",
        :entity_id => 2,
        :up => false
      )
    ])
  end

  it "renders a list of votes" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "tr>td", :text => 1.to_s, :count => 2
    assert_select "tr>td", :text => "Entity Type".to_s, :count => 2
    assert_select "tr>td", :text => 2.to_s, :count => 2
    assert_select "tr>td", :text => false.to_s, :count => 2
  end
end
