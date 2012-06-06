class RcpqueriesController < ApplicationController
  filter_access_to :all
  
private
  # Get the current query for the current user and a stipulated owner, 
  # making a new one as necessary
    def current_query(owner)
        uid = session[:user_id]
        # Either we're dealing with an existing query, or not
        session[:rcpquery] = nil if session[:rcpquery].class != Fixnum
        @rcpquery = nil
        begin
            @rcpquery = session[:rcpquery] && Rcpquery.find(session[:rcpquery])
        rescue ActiveRecord::RecordNotFound => e
            # No need to take action; we'll create a new query below
        end
        unless @rcpquery && (@rcpquery.user_id == uid)
            @rcpquery = Rcpquery.create :user_id=>uid, :owner_id=>uid 
        end
        if owner && User.exists?(owner.to_i) && (@rcpquery.owner_id != owner.to_i) # Check against bogus uids
            @rcpquery.owner_id = owner.to_i
            @rcpquery.save
        end
        session[:rcpquery] = @rcpquery.id
        @rcpquery
    end

public
  # GET /rcpqueries
  # GET /rcpqueries.xml
  def index

    # We wake up with optional parameters:
    #   owner: id of list owner
    #   page: page in current query

    # Listing recipes doesn't require login, but we do need a user_id
    need_login false # ...doesn't require session: sets user_id to guest id if none
    @rcpquery = current_query params[:owner]
    # Blind index: show list of either the current user or a given user
    # NB: the list of special user 'guest' sees all public recipes
    # Ensure the quality of the query

    session[:querypage] = @rcpquery.cur_page = params[:page] || session[:querypage]
    @Title = @rcpquery.title
    @navlinks = []
    @nav_current = :cookmarks
    # respond_to do |format|
      # format.html index.html.erb
      # format.xml  { render :xml => @rcpqueries }
    # end
  end

  # GET /rcpqueries/1
  # GET /rcpqueries/1.xml
  def show
    session[:rcpquery] = params[:id].to_i
    session[:querypage] = @rcpquery.cur_page = params[:page] || session[:querypage]
    redirect_to rcpqueries_url

    # respond_to do |format|
      # format.html show.html.erb
      # format.xml  { render :xml => @rcpquery }
    # end
  end

  # GET /rcpqueries/new
  # GET /rcpqueries/new.xml
  def new
    @rcpquery = Rcpquery.new 
    @rcpquery.user_id = @rcpquery.owner_id = session[:user_id]
    @rcpquery.save
    session[:rcpquery] = @rcpquery.id
    redirect_to rcpqueries_url
  end

  # GET /rcpqueries/1/edit
  def edit
    session[:rcpquery] = params[:id].to_i
    redirect_to rcpqueries_url
  end

  # POST /rcpqueries
  # POST /rcpqueries.xml
  # Take parameters revising the current query
  def create
    
    @rcpquery = current_query session[:user_id]
	@rcpquery.update_attributes(params[:rcpquery])
    @rcpquery.save
    session[:querypage] = @rcpquery.cur_page = params[:page] || session[:querypage]
    @Title = "Query from Create"
    redirect_to rcpqueries_url

    # respond_to do |format|
      # if @rcpquery.save
        # format.html { redirect_to(@rcpquery, :notice => 'Rcpquery was successfully created.') }
        # format.xml  { render :xml => @rcpquery, :status => :created, :location => @rcpquery }
      # else
        # format.html { render :action => "new" }
        # format.xml  { render :xml => @rcpquery.errors, :status => :unprocessable_entity }
      # end
    # end
  end

  # /rcpqueries/relist: fire back the recipe list based on a change in status, mode, style or page number
  # (without such a parameter, it just refreshes the list from the current query)
  def relist
      # Presumably the params include :status, :querymode and/or :listmode specs
      @rcpquery = Rcpquery.fetch_revision(session[:rcpquery], session[:user_id], params)
      session[:rcpquery] = @rcpquery.id # In case the model decided on a new query
      session[:querypage] = @rcpquery.cur_page = params[:page] || session[:querypage]
      render '_form_rcplist.html.erb', :layout=>false
  end

  # PUT /rcpqueries/1
  # PUT /rcpqueries/1.xml
  # POST /rcpqueries/1
  # POST /rcpqueries/1.xml
  def update
    # Respond to a form submission (query params are in params[:rcpquery])
    @rcpquery = Rcpquery.fetch_revision(params[:id].to_i, session[:user_id], params[:rcpquery])
    session[:rcpquery] = @rcpquery.id

    session[:querypage] = @rcpquery.cur_page = params[:page] || session[:querypage]
    @Title = "Query from Update"
    element = params[:element].to_sym
    case element
    when :tabnum
       # Just send back the tab number
       render :text=>@rcpquery.status_tab.to_s
    when :querylist_header
       render '_form_rcplist_header.html.erb', :layout=>false
    when :rcplist_body
       render '_form_rcplist.html.erb', :layout=>false
    end

  end

  # DELETE /rcpqueries/1
  # DELETE /rcpqueries/1.xml
  def destroy
    @rcpquery = Rcpquery.find(params[:id])
    @rcpquery.destroy
    session[:rcpquery] = session[:querypage] = nil
    redirect_to rcpqueries_url

    # respond_to do |format|
      # format.html { redirect_to(rcpqueries_url) }
      # format.xml  { head :ok }
    # end
  end
end
