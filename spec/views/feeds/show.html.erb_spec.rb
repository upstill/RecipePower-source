require 'spec_helper'

describe "feeds/show.html.erb" do
  before(:each) do
    @feed = assign(:feed, stub_model(Feed,
      :url => "MyText",
      :type => "Type",
      :description => "Description",
      :site_id => 1
    ))
  end

  it "renders attributes in <p>" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    rendered.should match(/MyText/)
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    rendered.should match(/Type/)
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    rendered.should match(/Description/)
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    rendered.should match(/1/)
  end
end
