require 'spec_helper'

describe "referents/show.html.erb" do
  before(:each) do
    @referent = assign(:referent, stub_model(Referent,
      :term => 1
    ))
  end

  it "renders attributes in <p>" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    rendered.should match(/1/)
  end
end
