require 'spec_helper'

describe "mercury_pages/show" do
  before(:each) do
    page_ref = assign(:page_ref, stub_model(PageRef,
      :url => "MyText",
      :title => "MyText",
      :content => "MyText",
      :lead_image_url => "MyText",
      :domain => "Domain"
    ))
  end

  it "renders attributes in <p>" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    rendered.should match(/MyText/)
    rendered.should match(/MyText/)
    rendered.should match(/MyText/)
    rendered.should match(/MyText/)
    rendered.should match(/Domain/)
  end
end
