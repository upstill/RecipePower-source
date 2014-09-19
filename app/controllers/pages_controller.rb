class PagesController < ApplicationController
  layout :rs_layout
  # filter_access_to :all
  respond_to :html, :json
  
  def root
    if current_user
      redirect_to "/users/#{current_user.id}/collection" # collection_path
    else
      redirect_to home_path
    end
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
    x=2
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
  
  # Serve mobile page using the jqm layout
  def mobi
    response_service.is_mobile !params[:off] # Persists across page requests
    if current_user
      redirect_to collection_path
    else
      redirect_to home_path
    end
  end

  # Generic action for displaying a popup by name
  def popup
    params[:name] = params[:name].sub(/pages\//, '') # Legacy thing...
    response_service.is_dialog
    view_context.check_popup params[:name] # If we're serving the popup, remove it from the session
    smartrender action: params[:name]
  end

end
