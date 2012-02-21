require 'spec_helper'

describe "expressions/index.html.erb" do
  before(:each) do
    assign(:expressions, [
      stub_model(Expression,
        :tag_id => 1,
        :referent_id => 1,
        :form => 1,
        :locality => "Locality"
      ),
      stub_model(Expression,
        :tag_id => 1,
        :referent_id => 1,
        :form => 1,
        :locality => "Locality"
      )
    ])
  end

  it "renders a list of expressions" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "tr>td", :text => 1.to_s, :count => 2
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "tr>td", :text => 1.to_s, :count => 2
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "tr>td", :text => 1.to_s, :count => 2
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "tr>td", :text => "Locality".to_s, :count => 2
  end
end
