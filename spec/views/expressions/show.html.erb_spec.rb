require 'spec_helper'

describe "expressions/show.html.erb" do
  before(:each) do
    @expression = assign(:expression, stub_model(Expression,
      :tag_id => 1,
      :referent_id => 1,
      :form => 1,
      :locality => "Locality"
    ))
  end

  it "renders attributes in <p>" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    rendered.should match(/1/)
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    rendered.should match(/1/)
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    rendered.should match(/1/)
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    rendered.should match(/Locality/)
  end
end
