require 'spec_helper'

describe "thumbnails/edit.html.erb" do
  before(:each) do
    @thumbnail = assign(:thumbnail, stub_model(Thumbnail,
      :url => "MyText",
      :thumdata => "MyText",
      :thumbwid => 1,
      :thumbht => 1
    ))
  end

  it "renders the edit thumbnail form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form", :action => thumbnails_path(@thumbnail), :method => "post" do
      assert_select "textarea#thumbnail_url", :name => "thumbnail[url]"
      assert_select "textarea#thumbnail_thumdata", :name => "thumbnail[thumdata]"
      assert_select "input#thumbnail_thumbwid", :name => "thumbnail[thumbwid]"
      assert_select "input#thumbnail_thumbht", :name => "thumbnail[thumbht]"
    end
  end
end
