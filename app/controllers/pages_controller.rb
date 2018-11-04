class PagesController < ApplicationController
  # filter_access_to :all
  respond_to :html, :json

  # Present dialog for collecting a cookmark in a super-simple layout
  def collect
    if current_user
      @page_ref = PageRef.new
      render layout: 'collect'
    else
      login_required :login_direct => true
    end
  end

  def root
    redirect_to default_next_path # Either current user's home page (if any) or /home (if not)
  end

  def admin
    # session.delete :on_tour # Tour's over!
    response_service.title = 'Admin'
  end

  def letsencrypt
    render :text => params[:id] + '.GtVR_lU6pWVrXyEuR0zbcl5uCyBrGfjBrwVOlZgtDPo'
  end

  def home
    response_service.title = 'Home'
    @auth_context = :manage
    @home_page = true
    if current_user
      redirect_to collection_user_path(current_user, params.slice(:trigger))
    else
      cache version: '1' do
        render
      end
    end
  end

  def contact
  	response_service.title = 'Contact'
    smartrender
  end

  def tell_me_more
    response_service.title = 'Cookmark'
    smartrender
  end

  def cookmark
    response_service.title = 'Cookmark'
    smartrender
  end

  def sprites
    render # layout: "naked"
  end

  def about
  	response_service.title = 'About'
    smartrender
  end

  def faq
    response_service.title = 'FAQ'
    smartrender
  end
  
  # Generic action for displaying a popup by name
  def popup
    # params[:name] = params[:name].sub(/pages\//, '') # Legacy thing...
    if pname = params[:name]
      view_context.check_popup pname # If we're serving the popup, remove it from the session
      smartrender action: pname, mode: :modal
    else
      # Either present the triggered dialog directly (JSON response) or via the home page
      if dialog = pending_modal_trigger
        # There's a modal pending
        respond_to do |format|
          format.html { render layout: 'signin' } # redirect_to view_context.page_with_trigger(home_path, dialog) }
          format.json { redirect_to dialog }
        end
      elsif page_request = request_matching(:format => :html)
        # There's a page pending
        respond_to do |format|
          format.html { redirect_to page_request }
          format.json { redirect_to goto_url( to: %Q{"#{page_request}"}) }
        end
      else
        respond_to do |format|
          format.html { redirect_to home_path }
          format.json { render action: "done" }
        end
      end
    end
  end

  private

  def page_params
    params.require(:page).permit!
  end

end
