class PagesController < ApplicationController
  # filter_access_to :all
  respond_to :html, :json
  
  def root
    redirect_to collection_path # ...but only if current user
  end

  def admin
    # session.delete :on_tour # Tour's over!
    response_service.title = "Admin"
  end

  def home
    response_service.title = "Home"
    @auth_context = :manage
    # setup_collection
    render
  end

  def contact
  	response_service.title = "Contact"
    smartrender
  end

  def about
  	response_service.title = "About"
    smartrender
  end

  def faq
    response_service.title = "FAQ"
    smartrender
  end
  
  # Generic action for displaying a popup by name
  def popup
    # params[:name] = params[:name].sub(/pages\//, '') # Legacy thing...
    if params[:name]
      view_context.check_popup params[:name] # If we're serving the popup, remove it from the session
      smartrender action: params[:name], mode: :modal
    else
      # Either present the triggered dialog directly (JSON response) or via the home page
      dialog = response_service.pending_modal_trigger
      respond_to do |format|
        format.html { redirect_to view_context.page_with_trigger(home_path, dialog) }
        format.json { redirect_to dialog }
      end
    end
  end

end
