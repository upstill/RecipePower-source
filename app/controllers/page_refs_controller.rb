
class PageRefsController < CollectibleController
  require 'page_ref.rb'
  before_action :set_page_ref, only: [:show, :edit, :update, :destroy]
  before_action :allow_iframe, only: :tag
  before_action :login_required, :except => [:create, :touch, :index, :show, :associated, :capture, :collect, :card ]

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
    @page_ref = PageRef.new kind: 'recipe', url: 'http://www.example.com'
    smartrender
  end

  # GET /page_refs/1/edit
  def edit
    update_and_decorate
    smartrender
  end

  # POST /page_refs
  # Soecial, super-simple page for collecting a cookmark
  # With no parameters, we display the dialog for collecting a URL and Kind
  # With URL and Kind parameters, we try to create the appropriate entity
  #   -- Is there a user logged in?
  #     N: redirect to [collect the enitity after logging in]
  #     Y: can the entity be collected?
  #       Y: display a success report and a link to the entity on RecipePower
  #       N: redraw the dialog with a flash error
  def create
    if current_user
      @entity = @page_ref = PageRefServices.assert params[:page_ref][:kind], params[:page_ref][:url]
      if @page_ref.errors.empty?
        @page_ref.bkg_land
        update_and_decorate @page_ref # Applies other parameters
        @entity = RefereeServices.new(@page_ref).assert_kind params[:page_ref][:kind], true
        @entity.bkg_land
      end
      respond_to do |format|
        format.json {
          # JSON format is for dialogs creating a page_ref
          if @page_ref.errors.present?
            render json: view_context.flash_notify(@page_ref, false)
          else
            render json: @page_ref.attributes.slice('id', 'url', 'kind', 'title')
          end
        }
        format.html {
          # This is from the "dialog" in the 'collect' layout. Response depends on errors:
          #   * No errors: present an equally simple page with dialog offering a link to the entity on RecipePower
          #   * Errors: re-render the dialog with an error flash and the provided parameters
          if @entity.errors.present?
            resource_errors_to_flash @entity
            render 'pages/collect', layout: 'collect'
          else
            render layout: 'collect'
          end
        }
      end
    else # No user logged in => stash request pending login and redirect to #home
      login_required :format => :json # To get a dialog
    end
  end

=begin
  # PATCH/PUT /page_refs/1
  # Handled in CollectibleController
  def update
    if page_ref.update page_ref_params
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
      page_ref = PageRef.find params[:id]
    end

    # Only allow a trusted parameter "white list" through.
    # NB: Provided by PageRef#mass_assignable_attributes
=begin
    def page_ref_params
      # :url and :domain cannot be mass-assigned b/c they have to be processed externally.
      # Specifically, a page_ref can be asserted for a novel url, but an existing page_ref is
      # DEFINED to be associated with a specific url. Hence it cannot be changed
      params.require(:page_ref).permit(:kind, :title, :picurl
    end
=end
end
