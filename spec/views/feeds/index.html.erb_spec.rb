require 'spec_helper'

describe "feeds/index.html.erb" do
  before(:each) do
    assign(:feeds, [
      stub_model(Feed,
        :url => "MyText",
        :type => "Type",
        :description => "Description",
        :site_id => 1
      ),
      stub_model(Feed,
        :url => "MyText",
        :type => "Type",
        :description => "Description",
        :site_id => 1
      )
    ])
  end

  it "renders a list of feeds" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "tr>td", :text => "MyText".to_s, :count => 2
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "tr>td", :text => "Type".to_s, :count => 2
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "tr>td", :text => "Description".to_s, :count => 2
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "tr>td", :text => 1.to_s, :count => 2
  end
end
