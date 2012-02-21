require 'spec_helper'

describe "referents/index.html.erb" do
  before(:each) do
    assign(:referents, [
      stub_model(Referent,
        :term => 1
      ),
      stub_model(Referent,
        :term => 1
      )
    ])
  end

  it "renders a list of referents" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "tr>td", :text => 1.to_s, :count => 2
  end
end
