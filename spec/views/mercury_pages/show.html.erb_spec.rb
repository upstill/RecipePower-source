require 'spec_helper'

describe "mercury_pages/show" do
  before(:each) do
    @mercury_page = assign(:mercury_page, stub_model(MercuryPage,
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
