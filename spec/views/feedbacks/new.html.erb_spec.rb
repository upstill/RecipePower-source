require 'spec_helper'

describe "feedbacks/new.html.erb" do
  before(:each) do
    assign(:feedback, stub_model(Feedback,
      :user_id => 1,
      :what => "MyText"
    ).as_new_record)
  end

  it "renders new feedback form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form", :action => feedbacks_path, :method => "post" do
      assert_select "input#feedback_user_id", :name => "feedback[user_id]"
      assert_select "textarea#feedback_what", :name => "feedback[what]"
    end
  end
end
