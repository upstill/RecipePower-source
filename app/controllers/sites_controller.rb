# require 'will_paginate'

class SitesController < ApplicationController
  # GET /sites
  # GET /sites.json
  def index
      # return if need_login true, true
    @sites = Site.all # paginate(:per_page => 5, :page => params[:page])
    
    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @sites }
    end
  end

  # GET /sites/1
  # GET /sites/1.json
  def show
      # return if need_login true, true
    @site = Site.find(params[:id])
    @Title = @site.name
    
    # Setup to display the feeds for the site
    @feeds = @site.feeds
    @seeker = FeedSeeker.new @feeds, session[:seeker] # Default; other controllers may set up different seekers

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @site }
    end
  end

  # GET /sites/new
  # GET /sites/new.json
  def new
      # return if need_login true, true
    @site = Site.new
    @Title = "New Site"

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @site }
    end
  end

  # GET /sites/1/edit
  def edit
    # return if need_login true, true
    @site = Site.find(params[:id].to_i)
    if params[:pic_picker]
      # Setting the pic_picker param requests a picture-editing dialog
      render :partial=> "shared/pic_picker"
    else
      @Title = @site.name
    end
  end

  # POST /sites
  # POST /sites.json
  def create
      # return if need_login true, true
    @site = Site.new(params[:site])

    respond_to do |format|
      if @site.save
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
      # return if need_login true, true
    @site = Site.find(params[:id])
    respond_to do |format|
      if @site.update_attributes(params[:site])
        format.html { redirect_to @site, notice: 'Site was successfully updated.' }
        format.json { head :ok }
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
    @site = Site.find(params[:id])
    @site.destroy

    respond_to do |format|
      format.html { redirect_to sites_url }
      format.json { head :ok }
    end
  end
  
  def scrape
    url = params[:url]
    if @site = Site.by_link(url)
      olist = @site.feeds.clone
      FeedServices.scrape_page @site, url
      @feeds = @site.feeds
      nlist = @feeds - olist
      if nlist.empty?
        codicil = olist.empty? ? ". " : view_context.list_feeds(", though the site already has", olist)
        redirect_to "/feeds/new", notice: "No new feeds found in page#{codicil}If you want more, you might try copy-and-paste-ing RSS URLs individually."
      else
        @site.save
        @seeker = FeedSeeker.new @feeds, session[:seeker] # Default; other controllers may set up different seekers
        flash.now[:notice] = view_context.list_feeds("Scraped", nlist)
        render action: :show
      end
    else
      redirect_to "/feeds/new", notice: "Couldn't make sense of URL"
    end
  end
end
