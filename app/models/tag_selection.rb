# This model is for persisting part of the user's profile: the Q&A where the
# answers are in the form of a tag
class TagSelection < ApplicationRecord
  belongs_to :tagset
  belongs_to :user
  belongs_to :tag
  delegate :title, :to => :tagset
  attr_reader :tag_token
  # attr_accessible :tag_token, :user, :user_id, :tagset, :tagset_id, :tag

  def tag_token= t
    token = TokenInput.parse_tokens(t).first # parse_tokens analyzes each token in the list as either integer or string
    self.tag = token.is_a?(Integer) ?
        Tag.find(token) :
        Tag.strmatch(token, { userid: user_id, assert: true }.compact )[0] # Match or assert the string
    @tag_token = tag.id
  end
end
