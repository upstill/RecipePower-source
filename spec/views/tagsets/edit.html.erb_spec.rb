require 'spec_helper'

describe "tagsets/edit" do
  before(:each) do
    @tagset = assign(:tagset, stub_model(Tagset))
  end

  it "renders the edit tagset form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form[action=?][method=?]", tagset_path(@tagset), "post" do
    end
  end
end
