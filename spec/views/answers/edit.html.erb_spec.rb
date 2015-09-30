require 'spec_helper'

describe "answers/edit" do
  before(:each) do
    @answer = assign(:answer, stub_model(Answer,
      :answer => "MyString",
      :user => nil,
      :question_id => 1
    ))
  end

  it "renders the edit answer form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form[action=?][method=?]", answer_path(@answer), "post" do
      assert_select "input#answer_answer[name=?]", "answer[answer]"
      assert_select "input#answer_user[name=?]", "answer[user]"
      assert_select "input#answer_question_id[name=?]", "answer[question_id]"
    end
  end
end
