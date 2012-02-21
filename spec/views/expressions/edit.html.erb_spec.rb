require 'spec_helper'

describe "expressions/edit.html.erb" do
  before(:each) do
    @expression = assign(:expression, stub_model(Expression,
      :tag_id => 1,
      :referent_id => 1,
      :form => 1,
      :locality => "MyString"
    ))
  end

  it "renders the edit expression form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form", :action => expressions_path(@expression), :method => "post" do
      assert_select "input#expression_tag_id", :name => "expression[tag_id]"
      assert_select "input#expression_referent_id", :name => "expression[referent_id]"
      assert_select "input#expression_form", :name => "expression[form]"
      assert_select "input#expression_locality", :name => "expression[locality]"
    end
  end
end
