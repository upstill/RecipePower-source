require 'spec_helper'

describe "referents/edit.html.erb" do
  before(:each) do
    @referent = assign(:referent, stub_model(Referent,
      :term => 1
    ))
  end

  it "renders the edit referent form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form", :action => referents_path(@referent), :method => "post" do
      assert_select "input#referent_term", :name => "referent[term]"
    end
  end
end
