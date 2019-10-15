
class SitesController < CollectibleController
  before_action :set_site, only: [:show, :edit, :update, :destroy]

  # GET /sites
  # GET /sites.json
  def index
    # seeker_result Site, "div.site_list" # , clear_tags: true
    response_service.title = 'Sites'
    smartrender 
  end

  def feeds
    update_and_decorate
    smartrender
  end

  # POST /sites
  # POST /sites.json
  def create
    @site = Site.create site_params
    respond_to do |format|
      if @site.errors.empty?
        format.html { redirect_to @site, notice: 'Site was successfully created.' }
        format.json { render json: @site, status: :created, location: @site }
      else
        format.html { render action: 'new' }
        format.json { render json: @site.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /sites/1
  # PUT /sites/1.json
  def update
    # TODO: see if mass-assigning gleaning_attributes works in Rails 5
    gleanings = params[:site].delete :gleaning_attributes
    if update_and_decorate
      if @site.errors.empty?
        @site.gleaning_attributes = gleanings
        respond_to do |format|
          format.html { redirect_to @site, notice: "Site #{@site.name} was successfully updated." }
          format.json {
            flash[:popup] = "#{@site.name} updated"
            render :update
          }
        end
        return
      end
    end
    if @site
      resource_errors_to_flash @site
    else
      flash[:alert] = 'Couldn\'t fetch site'
    end
    smartrender :action => :edit
  end

  private

  def set_site
    @site = Site.find params[:id]
  end

  def site_params
    permitted_attributes = Site.mass_assignable_attributes + [
      :name, :description, :home, :root, :ttlcut, :logo,
      :finders_attributes => %w{ label selector attribute_name _destroy id }
    ]
    params.require(:site).permit *permitted_attributes
  end
end
