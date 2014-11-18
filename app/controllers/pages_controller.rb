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
    # session.delete :on_tour # Tour's over!
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
    params[:name] = params[:name].sub(/pages\//, '') # Legacy thing...
    view_context.check_popup params[:name] # If we're serving the popup, remove it from the session
    smartrender action: params[:name], mode: :modal
  end

end
