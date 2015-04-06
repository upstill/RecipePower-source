class Answer < ActiveRecord::Base
  belongs_to :user
  belongs_to :question, :class_name => "Tag"
  attr_accessible :answer, :question_id, :user_id
end
