class TagSelection < ActiveRecord::Base
  belongs_to :tagset
  belongs_to :user
  belongs_to :tag
  delegate :title, :to => :tagset
  attr_reader :tag_token
  attr_accessible :tag_token, :user, :tagset, :tag, :tagset_id

  def tag_token= t
    token = TokenInput.parse_tokens(t).first # parse_tokens analyzes each token in the list as either integer or string
    self.tag = token.is_a?(Fixnum) ?
        Tag.find(token) :
        Tag.strmatch(token, userid: user.id, assert: true)[0] # Match or assert the string
    @tag_token = tag.id
  end
end
