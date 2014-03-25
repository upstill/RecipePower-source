require 'spec_helper'

describe "votes/show" do
  before(:each) do
    @vote = assign(:vote, stub_model(Vote,
      :user_id => 1,
      :entity_type => "Entity Type",
      :entity_id => 2,
      :up => false
    ))
  end

  it "renders attributes in <p>" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    rendered.should match(/1/)
    rendered.should match(/Entity Type/)
    rendered.should match(/2/)
    rendered.should match(/false/)
  end
end
