class TagSelectionsController < ApplicationController

  def update
    update_and_decorate
    flash[:popup] = 'Selection duly noted.'
    render :create, layout: false
  end

  def create
    # Avoid creating another selection for a given user and tagset
    ts = TagSelection.find_or_create_by tag_selection_params.slice(:user_id, :tagset_id)
    update_and_decorate ts
    flash[:popup] = 'Selection duly noted.'
    render :create, layout: false
  end

  private

  def tag_selection_params
    params.require(:tag_selection).permit!
  end
end
