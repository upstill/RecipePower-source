require 'spec_helper'

describe "referents/new.html.erb" do
  before(:each) do
    assign(:referent, stub_model(Referent,
      :term => 1
    ).as_new_record)
  end

  it "renders new referent form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form", :action => referents_path, :method => "post" do
      assert_select "input#referent_term", :name => "referent[term]"
    end
  end
end
