class Answer < ApplicationRecord
  belongs_to :user
  belongs_to :question, :class_name => "Tag"
  attr_accessible :answer, :question, :question_id, :user_id
end
