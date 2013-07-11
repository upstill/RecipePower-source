class PagesController < ApplicationController
  # filter_access_to :all
  respond_to :html, :json
  def home
    session.delete :on_tour # Tour's over!
  	@Title = "Home"
    @auth_context = :manage
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
  
  def popup
    respond_with do |format|
      format.json { 
        render json: {
          dlog: with_format("html") { render_to_string :partial => params[:name] }
        }
      }
    end
  end

  def share 
    @resource = User.new( )
    @resource.invitation_issuer = "Some Geek"
    @resource.invitation_message = "Come on down!"
    @resource.invitation_token = "jlkjkjvoiwe"
    @recipe = Recipe.all.first { |rcp| params[:nothumb] ? !rcp.thumbnail : rcp.thumbnail }
    render layout: "share_instructions"
  end
end
