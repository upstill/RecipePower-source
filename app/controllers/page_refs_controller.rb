class PageRefsController < CollectibleController
  require 'page_ref.rb'
  before_action :set_page_ref, only: [:show, :edit, :update, :destroy]
  before_filter :allow_iframe, only: :tag

  # GET /page_refs
  def index
    page_refs = PageRef.all
  end

  # GET /page_refs/1
  def show
    update_and_decorate
    smartrender
  end

  # GET /page_refs/new
  def new
    @page_ref = DefinitionPageRef.new
    smartrender
  end

  # GET /page_refs/1/edit
  def edit
    update_and_decorate
    smartrender
  end

  # GET /page_refs/1/tag
  def tag # Collect URL from foreign site, asking whether to re-direct to edit
    # return if need_login true
    # Here is where we take a hit on the "Add to RecipePower" widget,
    # and also invoke the 'new cookmark' dialog. The difference is whether
    # parameters are supplied for url, title and note (though only URI is required).
    # Either get the pageref directly, via ID, or by creating one anew
    @page_ref = PageRefServices.find_or_create(params[:page_ref], params[:extractions])
    # pr.incoming_attributes params[:page_ref].keys
    @decorator = @page_ref.decorate
    if current_user
      # Ensure there's an associated collectible entity
      # NB: it's safe to build one now that we've got a logged-in user
      @resource = PageRefServices.new(@page_ref).entity(params)
        # The resource doesn't have to be a recipe
        # -- If there's a site matching this url, that gets returned
        # -- If there's a Tip, Video, etc. (anything with a PageRef), then that gets returned
      current_user.collect @resource
    end
    if request.method == 'GET'
      # Before editing, we need to ensure that parameters have been collected
      respond_to do |format|
        format.html { # This is for capturing a new recipe and tagging it using a new page.
          if current_user
            if response_service.injector?
              smartrender :action => :tag
            else
              # If we're collecting a recipe outside the context of the iframe, redirect to
              # the collection page with an embedded modal dialog invocation
              # tag_path = polymorphic_path [:tag, @resource]
              redirect_to_modal tag_page_ref_path(@page_ref)
            end
          else
            # Defer request, redirecting it for JSON
            login_required :json
          end
        }
        format.json {
          if current_user
            if @resource.id || @resource.errors.any?
              render :errors, locals: { entity: @resource }
            else
              smartrender
            end
          else
            # Not logged in => have to store recipe parameters (url, title, comment) in a safe place pending login
            # session[:pending_recipe] = params[:recipe].merge page_ref_id: @page_ref.id
            # After login, we'll be returned to this request to complete tagging
            login_required
          end
        }
      end
    else
      @page_ref.update_attributes params[:page_ref].except(:url, :type) # Bow to changed parameters
      @page_ref.save
      if resource_errors_to_flash(@page_ref)
        render :errors
      else
        flash[:popup] = "'#{@page_ref.truncate 50}' is all set."
        render 'collectible/update.json'
      end
    end
  end

  # POST /page_refs
  def create
    @page_ref = PageRefServices.assert params[:page_ref][:type], params[:page_ref][:url]

    if @page_ref.errors.any?
      resource_errors_to_flash @page_ref
      smartrender :new
    else
      case @page_ref.class
        when RecipePageRef
          # TODO: Ensure existence of recipe, and go there
        when SitePageRef
          # TODO: Ensure existence of site, and go there
        else
          smartrender :action => :edit
      end
    end
  end

  # PATCH/PUT /page_refs/1
  def update
    if page_ref.update(page_ref_params)
      redirect_to page_ref, notice: 'Mercury page was successfully updated.'
    else
      render :edit
    end
  end

  # DELETE /page_refs/1
=begin
  # Handled in ApplicationController
  def destroy
    page_ref.destroy
    redirect_to page_refs_url, notice: 'Mercury page was successfully destroyed.'
  end
=end

  def scrape
    begin
      render json: { popup: 'Scraped through ' + RecipePageRef.scrape(params[:first]) + '. Hit reload for next batch.' }
    rescue Exception => e
      render json: { alert: 'Scrape died: ' + e.to_s }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_page_ref
      page_ref = PageRef.find(params[:id])
    end

    # Only allow a trusted parameter "white list" through.
    def page_ref_params
      params.require(:page_ref).permit(:url, :title, :content, :date_published, :lead_image_url, :domain)
    end
end
