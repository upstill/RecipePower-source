class Feedback < ApplicationRecord
  # attr_accessible :id, :user_id, :subject, :email, :comment, :page, :docontact
  validates_presence_of :comment

=begin  
  def valid?
    self.comment && !self.comment.strip.blank?
  end
=end  
end
