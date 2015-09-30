require 'spec_helper'

describe "tagsets/new" do
  before(:each) do
    assign(:tagset, stub_model(Tagset).as_new_record)
  end

  it "renders new tagset form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form[action=?][method=?]", tagsets_path, "post" do
    end
  end
end
