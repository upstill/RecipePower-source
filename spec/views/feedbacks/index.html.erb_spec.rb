require 'spec_helper'

describe "feedbacks/index.html.erb" do
  before(:each) do
    assign(:feedbacks, [
      stub_model(Feedback,
        :user_id => 1,
        :what => "MyText"
      ),
      stub_model(Feedback,
        :user_id => 1,
        :what => "MyText"
      )
    ])
  end

  it "renders a list of feedbacks" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "tr>td", :text => 1.to_s, :count => 2
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "tr>td", :text => "MyText".to_s, :count => 2
  end
end
