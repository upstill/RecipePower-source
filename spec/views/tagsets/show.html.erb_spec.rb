require 'spec_helper'

describe "tagsets/show" do
  before(:each) do
    @tagset = assign(:tagset, stub_model(Tagset))
  end

  it "renders attributes in <p>" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
  end
end
