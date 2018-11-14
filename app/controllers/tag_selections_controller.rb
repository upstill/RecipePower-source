class TagSelectionsController < ApplicationController

  def update
    update_and_decorate
    flash[:popup] = 'Selection duly noted.'
    render :create, layout: false
  end

  def create
    # Avoid creating another selection for a given user and tagset
    tsp = tag_selection_params
    @tag_selection = TagSelection.create_with(tsp.except :user_id, :tagset_id).find_or_create_by tsp.slice(:user_id, :tagset_id)
    flash[:popup] = 'Selection duly noted.'
    render :create, layout: false
  end

  private

  def tag_selection_params
    params.require(:tag_selection).permit :user_id, :tagset_id, :tag_token
  end
end
