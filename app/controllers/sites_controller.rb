
class SitesController < CollectibleController

  # GET /sites
  # GET /sites.json
  def index
    # seeker_result Site, "div.site_list" # , clear_tags: true
    smartrender unless do_stream SitesCache
  end

  # GET /sites/1
  # GET /sites/1.json
  def show
    update_and_decorate
    smartrender
  end

  # GET /sites/new
  # GET /sites/new.json
  def new
    # return if need_login true, true
    update_and_decorate
    response_service.title = "New Site"
    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @site }
    end
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
        format.html { render action: "new" }
        format.json { render json: @site.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /sites/1
  # PUT /sites/1.json
  def update
    update_and_decorate
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
