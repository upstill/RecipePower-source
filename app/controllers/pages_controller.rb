class PagesController < ApplicationController
  layout :rs_layout
  # filter_access_to :all
  respond_to :html, :json
  
  def root
    if current_user
      redirect_to collection_path
    else
      redirect_to home_path
    end
  end
  
  def home
    # session.delete :on_tour # Tour's over!
    @Title = "Home"
    @auth_context = :manage
    setup_collection
  end

  def contact
  	@Title = "Contact"
    smartrender
  end

  def about
  	@Title = "About"
    smartrender
  end

  def faq
    @Title = "FAQ"
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
    respond_with do |format|
      format.json { 
        dlog = with_format("html") { render_to_string partial: params[:name] }
        render json: { dlog: dlog }
      }
    end
  end

end
