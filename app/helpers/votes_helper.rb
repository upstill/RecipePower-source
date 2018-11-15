module VotesHelper

  # Link to submit a vote on the given entity. 'up' is true for an upvote
  def vote_link entity, up, options={}
    assert_query "/votes/#{entity.class.base_class.model_name.param_key}/#{entity.id}", options.merge(up: up)
  end

end
