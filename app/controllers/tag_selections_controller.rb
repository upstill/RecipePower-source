class TagSelectionsController < ApplicationController

  def update
    update_and_decorate
    flash[:popup] = 'Selection duly noted.'
    render :create, layout: false
  end

  def create
    # Avoid creating another selection for a given user and tagset
    ts = TagSelection.find_or_create_by params[:tag_selection].slice(:user_id, :tagset_id)
    ts.update_attributes params[:tag_selection]
    ts.save
    update_and_decorate ts
    flash[:popup] = 'Selection duly noted.'
    render :create, layout: false
  end
end
