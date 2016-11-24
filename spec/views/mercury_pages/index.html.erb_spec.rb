require 'spec_helper'

describe "mercury_pages/index" do
  before(:each) do
    assign(:mercury_pages, [
      stub_model(MercuryPage,
        :url => "MyText",
        :title => "MyText",
        :content => "MyText",
        :lead_image_url => "MyText",
        :domain => "Domain"
      ),
      stub_model(MercuryPage,
        :url => "MyText",
        :title => "MyText",
        :content => "MyText",
        :lead_image_url => "MyText",
        :domain => "Domain"
      )
    ])
  end

  it "renders a list of mercury_pages" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "tr>td", :text => "MyText".to_s, :count => 2
    assert_select "tr>td", :text => "MyText".to_s, :count => 2
    assert_select "tr>td", :text => "MyText".to_s, :count => 2
    assert_select "tr>td", :text => "MyText".to_s, :count => 2
    assert_select "tr>td", :text => "Domain".to_s, :count => 2
  end
end
