
class SitesController < ApplicationController

  # GET /sites
  # GET /sites.json
  def index
    # seeker_result Site, "div.site_list" # , clear_tags: true
    @container = "container_collections"
    smartrender unless do_stream SitesCache
  end

  # GET /sites/1
  # GET /sites/1.json
  def show
    # return if need_login true, true
    @user = current_user_or_guest
    @site = Site.find(params[:id])
    @decorator = @site.decorate
    @decorator.viewer_id = @user.id
    response_service.title = @site.name
    
    smartrender modal: true # :how => :modal
  end

  # GET /sites/new
  # GET /sites/new.json
  def new
    # return if need_login true, true
    prep_params
    response_service.title = "New Site"
    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @site }
    end
  end

  # GET /sites/1/edit
  def edit
    # return if need_login true, true
    prep_params # Give collectible and taggable a chance to set up their parameters
    response_service.title = @site.name
    smartrender area: "floating"
  end

  # POST /sites
  # POST /sites.json
  def create
      # return if need_login true, true
    respond_to do |format|
      accept_params
      if !@site.errors.any?
        format.html { redirect_to @site, notice: 'Site was successfully created.' }
        format.json { render json: @site, status: :created, location: @site }
      else
        format.html { render action: "new" }
        format.json { render json: @site.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /sites/1
  # PUT /sites/1.json
  def update
    accept_params
    respond_to do |format|
      if !@site.errors.any?
        format.html { redirect_to @site, notice: 'Site was successfully updated.' }
        format.json { 
          render json: { 
                         done: true, # Denotes recipe-editing is finished
                         popup: "#{@site.name} updated",
                         replacements: [
                           ["tr#site#{@site.id.to_s}", with_format("html") { render_to_string partial: "sites/index_table_row", locals: { item: @site } }]
                         ]
                       } 
      }
      else
        format.html { render action: "edit" }
        format.json { render json: @site.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /sites/1
  # DELETE /sites/1.json
  def destroy
    # return if need_login true, true
    @site = Site.find params[:id]
    @site.destroy
    respond_to do |format|
      format.html { redirect_to sites_url }
      format.json { head :ok }
    end
  end
  
  def scrape
    url = params[:url]
    if @site = Site.find_or_create(url)
      olist = @site.feeds.clone
      FeedServices.scrape_page @site, url
      @feeds = @site.feeds
      nlist = @feeds - olist
      if nlist.empty?
        codicil = olist.empty? ? ". " : view_context.list_feeds(", though the site already has", olist)
        redirect_to "/feeds/new", notice: "No new feeds found in page#{codicil}If you want more, you might try copy-and-paste-ing RSS URLs individually."
      else
        @site.save
        @user = current_user
        render action: :show
      end
    else
      redirect_to "/feeds/new", notice: "Couldn't make sense of URL"
    end
  end
end
