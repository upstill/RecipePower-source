require 'spec_helper'

describe "feeds/edit.html.erb" do
  before(:each) do
    @feed = assign(:feed, stub_model(Feed,
      :url => "MyText",
      :type => "",
      :description => "MyString",
      :site_id => 1
    ))
  end

  it "renders the edit feed form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form", :action => feeds_path(@feed), :method => "post" do
      assert_select "textarea#feed_url", :name => "feed[url]"
      assert_select "input#feed_type", :name => "feed[type]"
      assert_select "input#feed_description", :name => "feed[description]"
      assert_select "input#feed_site_id", :name => "feed[site_id]"
    end
  end
end
