require 'spec_helper'

describe "expressions/new.html.erb" do
  before(:each) do
    assign(:expression, stub_model(Expression,
      :tag_id => 1,
      :referent_id => 1,
      :form => 1,
      :locality => "MyString"
    ).as_new_record)
  end

  it "renders new expression form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form", :action => expressions_path, :method => "post" do
      assert_select "input#expression_tag_id", :name => "expression[tag_id]"
      assert_select "input#expression_referent_id", :name => "expression[referent_id]"
      assert_select "input#expression_form", :name => "expression[form]"
      assert_select "input#expression_locality", :name => "expression[locality]"
    end
  end
end
