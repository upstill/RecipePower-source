
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
    @page_ref = PageRef.new kind: 'recipe'
    smartrender
  end

  # GET /page_refs/1/edit
  def edit
    update_and_decorate
    smartrender
  end

  # GET /page_refs/1/tag
  # This is the followup to Recipes#capture, taking a url and a collection of extracted data,
  # producing a page_ref to match, then finding/creating a collectible entity from that
  # In the case of Recipes and Sites, that entity is different from the PageRef; otherwise
  # it's the same.
  # Regardless, we throw up the tagging dialog, which returns to the #tag method for setting
  # the appropriate attributes.
  def tag
    return super unless request.method == 'GET' && current_user # We have exclusive responsibility for setting up tagging
    # Either get the pageref directly, via ID, or by creating one anew
    # Either way, establish the desired type and url for the page_ref
    if page_ref = PageRef.find_by(id: params[:id]) # ...if we're coming here to tag a PageRef
      kind, url = page_ref.kind, page_ref.url
    elsif params[:page_ref]
      kind, url = (params[:page_ref][:kind] || 'recipe'), params[:page_ref][:url]
    else
      kind, url = 'recipe', nil
    end
    # Construct a valid URL from the given url and the extracted URI or href
    # Prefer the url from the extractions
    if params[:extractions]
      url = valid_url(params[:extractions]['URI'], url) || valid_url(params[:extractions]['href'], url) || url
    end
    # Now we compare the submitted page_ref, if any, to the requisite kind and URL
    page_ref = PageRef.fetch(url) unless page_ref && page_ref.answers_to?(url)

    # Ensure there's an associated collectible entity
    # NB: it's safe to build one now that we've got a logged-in user
    # The entity is what we're "really" tagging, even though
    # the dialog keys on a page_ref.
    # This means we need to
    # 1) ensure the existence of the resource
    # 2) copy and save any parameters or extractions for it
    # 3) ensure that the user has collected it

    # Initialize the entity from parameters and extractions, as needed
    entity = PageRefServices.new(page_ref).ensure_accompanying_entity params
    # Translate the :page_ref parameters to a collection aimed at this entity
    # params[entity.model_name.param_key] = page_ref.decorate.translate_params params[:page_ref].slice(:title, :url), entity
    update_and_decorate entity # , update_attributes: !entity.persisted?
    if entity.save # Finally! Save the object
      current_user.collect entity
      entity.bkg_launch # Scrape the page for other attributes in background
    end
    respond_to do |format|
      format.html {# This is for capturing a new recipe and tagging it using a new page.
        if response_service.injector?
          smartrender
        else
          # If we're collecting a recipe outside the context of the iframe, redirect to
          # the collection page with an embedded modal dialog invocation
          redirect_to_modal polymorphic_path(:tag, entity)
        end
      }
      format.json {
        if entity.errors.any?
          render :errors, locals: {entity: entity}
        else
          smartrender
        end
      }
    end
  end

  # POST /page_refs
  def create
    @page_ref = PageRefServices.assert(params[:page_ref][:kind], params[:page_ref][:url])
    if @page_ref.errors.any?
      resource_errors_to_flash @page_ref
    else
      @page_ref.bkg_land
      update_and_decorate @page_ref
    end
    respond_to do |format|
      format.json {
        if @page_ref.errors.any?
          render 'application/errors'
        else
          render json: @page_ref.attributes.slice( 'id', 'url', 'kind', 'title' )
        end
      }
      format.html { }
    end
=begin
    if @page_ref.errors.any?
      resource_errors_to_flash @page_ref
      smartrender :new
    else
      redirect_to tag_page_ref_path(@page_ref, :mode => :modal)
    end
=end
    end

=begin
  # PATCH/PUT /page_refs/1
  # Handled in CollectibleController
  def update
    if page_ref.update(page_ref_params)
      redirect_to page_ref, notice: 'Mercury page was successfully updated.'
    else
      render :edit
    end
  end
=end

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
      render json: { popup: 'Scraped through ' + PageRef.scrape(params[:first]) + '. Hit reload for next batch.' }
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
