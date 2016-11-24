require 'spec_helper'

describe "mercury_pages/new" do
  before(:each) do
    assign(:mercury_page, stub_model(MercuryPage,
      :url => "MyText",
      :title => "MyText",
      :content => "MyText",
      :lead_image_url => "MyText",
      :domain => "MyString"
    ).as_new_record)
  end

  it "renders new mercury_page form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form[action=?][method=?]", mercury_pages_path, "post" do
      assert_select "textarea#mercury_page_url[name=?]", "mercury_page[url]"
      assert_select "textarea#mercury_page_title[name=?]", "mercury_page[title]"
      assert_select "textarea#mercury_page_content[name=?]", "mercury_page[content]"
      assert_select "textarea#mercury_page_lead_image_url[name=?]", "mercury_page[lead_image_url]"
      assert_select "input#mercury_page_domain[name=?]", "mercury_page[domain]"
    end
  end
end
