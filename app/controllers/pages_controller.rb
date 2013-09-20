class PagesController < ApplicationController
  # filter_access_to :all
  respond_to :html, :json
  
  before_filter :define_query
  
  def define_query
	end
  
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
  end

  def about
  	@Title = "About"
  end

  def faq
    @Title = "FAQ"
  end
  
  # Serve mobile page using the jqm layout
  def mobi
    @area = "mobile"
    render layout: "jqm"
  end
  
  def popup
    respond_with do |format|
      format.json { 
        render json: {
          dlog: with_format("html") { render_to_string :partial => params[:name] }
        }
      }
    end
  end

end
