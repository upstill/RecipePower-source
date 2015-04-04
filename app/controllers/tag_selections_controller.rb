class TagSelectionsController < ApplicationController

  def update
    update_and_decorate
    redirect_to "/users/#{@tag_selection.user_id}/collection"
  end
end
