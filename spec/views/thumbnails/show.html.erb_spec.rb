require 'spec_helper'

describe "thumbnails/show.html.erb" do
  before(:each) do
    @thumbnail = assign(:thumbnail, stub_model(Thumbnail,
      :url => "MyText",
      :thumdata => "MyText",
      :thumbwid => 1,
      :thumbht => 1
    ))
  end

  it "renders attributes in <p>" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    rendered.should match(/MyText/)
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    rendered.should match(/MyText/)
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    rendered.should match(/1/)
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    rendered.should match(/1/)
  end
end
