
class SitesController < CollectibleController

  # GET /sites
  # GET /sites.json
  def index
    # seeker_result Site, "div.site_list" # , clear_tags: true
    response_service.title = 'Sites'
    smartrender 
  end

=begin Controller methods handled at the Collectible level
  # GET /sites/1
  # GET /sites/1.json
  def show
    update_and_decorate
    smartrender
  end

  def edit
    update_and_decorate
    @site.glean unless @site.gleaning
    response_service.title = 'Edit Site'
    smartrender
  end

  # POST site/:id/glean
  def glean
    update_and_decorate
    @site.glean! true
    render 'collectible/update' # redirect_to :action => 'update'
  end

  # GET /sites/new
  # GET /sites/new.json
  def new
    # return if need_login true, true
    update_and_decorate
    response_service.title = 'New Site'
    render :edit
  end
=end

  def feeds
    update_and_decorate
    smartrender
  end

  # POST /sites
  # POST /sites.json
  def create
    update_and_decorate 
    respond_to do |format|
      if !@site.errors.any?
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
    if update_and_decorate
      # @site.include_url(params[:site][:home], true) if params[:site][:home].present?
      unless @site.errors.any?
        @site.gleaning_attributes = params[:site][:gleaning_attributes]
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

  # DELETE /sites/1
  # DELETE /sites/1.json
=begin
  def destroy
    # return if need_login true, true
    @site = Site.find params[:id]
    @site.destroy
    respond_to do |format|
      format.html { redirect_to sites_url }
      format.json { head :ok }
    end
  end
=end
end
