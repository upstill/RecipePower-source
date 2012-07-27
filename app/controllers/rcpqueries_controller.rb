class RcpqueriesController < ApplicationController
  filter_access_to :all
  
private
  # Get the current query for the current user and a stipulated owner, 
  # making a new one as necessary
    def current_query(owner)
        @user_id = current_user_or_guest_id # session[:user_id]
        # Either we're dealing with an existing query, or not
        session[:rcpquery] = nil if session[:rcpquery].class != Fixnum
        @rcpquery = nil
        begin
            @rcpquery = session[:rcpquery] && Rcpquery.find(session[:rcpquery])
        rescue ActiveRecord::RecordNotFound => e
            # No need to take action; we'll create a new query below
        end
        unless @rcpquery && (@rcpquery.user_id == @user_id)
            @rcpquery = Rcpquery.create :user_id=>@user_id, :owner_id=>@user_id 
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
    @rcpquery = current_query params[:owner]
    @Title = "Cookmarks"
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
    redirect_to rcpqueries_url

    # respond_to do |format|
      # format.html show.html.erb
      # format.xml  { render :xml => @rcpquery }
    # end
  end

  # GET /rcpqueries/new
  # GET /rcpqueries/new.xml
  def new
    # We handle optional parameters:
    #   owner: id of list owner
    #   tag: number of tag to initialize query with
    @user_id = current_user_or_guest_id # session[:user_id]
    @rcpquery = Rcpquery.new(user_id: @user_id,
                             owner_id: (params[:owner] || @user_id).to_i)
    @rcpquery.tag_ids = [params[:tag].to_i] if params[:tag]
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
    @user_id = current_user_or_guest_id # session[:user_id]
    @rcpquery = current_query @user_id
	@rcpquery.update_attributes(params[:rcpquery])
    @rcpquery.save
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

  # /rcpqueries/relist: fire back the recipe list based on a change in status or page number
  # (without such a parameter, it just refreshes the list from the current query)
  def relist
      # Presumably the params include :status, :querymode and/or :listmode specs
      @user_id = current_user_or_guest_id # session[:user_id]
      if params[:id] # Query may be specified by id (currently only for profiling)
          @rcpquery = Rcpquery.where(:id => params[:id]).first || 
	  	      Rcpquery.create(user_id: User.guest_id, owner_id: User.guest_id)
      else
          @rcpquery = Rcpquery.fetch_revision(session[:rcpquery], @user_id, params)
      end
      session[:rcpquery] = @rcpquery.id # In case the model decided on a new query
      @list_name = @rcpquery.which_list
      render '_form_rcplist.html.erb', :layout=>false
  end
  
  # Return the recipe list for a tab in the 'mine' list. 
  # The only parameter is 'status', denoting the tab involved
  def tablist
      @user_id = current_user_or_guest_id
      @rcpquery = Rcpquery.fetch_revision(session[:rcpquery], @user_id, params)
      render '_form_placeholder.html.erb', :layout=>false
  end

  # PUT /rcpqueries/1
  # PUT /rcpqueries/1.xml
  # POST /rcpqueries/1
  # POST /rcpqueries/1.xml
  def update
    # Respond to a form submission (query params are in params[:rcpquery])
    @user_id = current_user_or_guest_id # session[:user_id]
    @rcpquery = Rcpquery.fetch_revision(params[:id].to_i, @user_id, params[:rcpquery])
    session[:rcpquery] = @rcpquery.id

    @Title = "Query from Update"
    @list_name = @rcpquery.which_list
    if params[:element] 
        case params[:element].to_sym
        when :tabnum
           # Just send back the tab number
           render :text=>@rcpquery.status_tab.to_s
        when :rcplist_body
           render '_form_rcplist.html.erb', :layout=>false
       end
    else
       # Without an element named, redirect to the whole page
       redirect_to rcpqueries_url
    end

  end

  # DELETE /rcpqueries/1
  # DELETE /rcpqueries/1.xml
  def destroy
    begin
        Rcpquery.find(params[:id]).destroy
    rescue # No need to do anything with failure
    end
    session[:rcpquery] = nil
    redirect_to rcpqueries_url

    # respond_to do |format|
      # format.html { redirect_to(rcpqueries_url) }
      # format.xml  { head :ok }
    # end
  end
end
