require 'spec_helper'

describe "sites/new.html.erb" do
  before(:each) do
    assign(:site, stub_model(Site,
      :domain => "MyString",
      :home => "MyString",
      :name => "MyString",
      :sample => "MyString",
      :logo => "MyString",
      :tags => "MyText"
    ).as_new_record)
  end

  it "renders new site form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form", :action => sites_path, :method => "post" do
      assert_select "input#site_domain", :name => "site[domain]"
      assert_select "input#site_home", :name => "site[home]"
      assert_select "input#site_name", :name => "site[name]"
      assert_select "input#site_sample", :name => "site[sample]"
      assert_select "input#site_logo", :name => "site[logo]"
      assert_select "textarea#site_tags", :name => "site[tags]"
    end
  end
end
