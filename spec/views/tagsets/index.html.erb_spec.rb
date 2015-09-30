require 'spec_helper'

describe "tagsets/index" do
  before(:each) do
    assign(:tagsets, [
      stub_model(Tagset),
      stub_model(Tagset)
    ])
  end

  it "renders a list of tagsets" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
  end
end
