class ReferentsController < ApplicationController
    # Here's where we defer to different handlers for different types of referent
    @@HandlersByIndex = [ Referent, GenreReferent, CourseReferent, 
            ProcessReferent, FoodReferent, UnitReferent, 
            PublicationReferent, AuthorReferent, OccasionReferent, 
            PantrySectionReferent, StoreSectionReferent, CircleReferent, ToolReferent ]
    @@HandlerClass = Referent
  # GET /referents
  # GET /referents.json
  def index
    @tabindex = session[:tabindex] || params[:tabindex] || 0
    handlerclass = @@HandlersByIndex[@tabindex]
    # We accept a query for chidren of a parent (or roots, if parentid == 0)
    if params[:key]
        parentid = params[:key].to_i
        # This is a JSON request for node data (re Dynatree)
        if parentid > 0
            parent = handlerclass.find parentid
            @referents = parent.children
        else
            @referents = handlerclass.roots
        end
        # Convert the referents to a JSON response
        @referents.sort! { |r1, r2| r1.name <=> r2.name }
        @nodes = @referents.map { |r| { :title=>r.longname, :isLazy=>true, :key=>r.id, :isFolder=>!r.leaf? }}
    else
        @referents = handlerclass.all
        @referents.sort! { |r1, r2| r1.name <=> r2.name }
    end

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @nodes }
    end
  end

  # GET /referents/1
  # GET /referents/1.json
  def show
      @tabindex = session[:tabindex] || params[:tabindex] || 0
      handlerclass = @@HandlersByIndex[@tabindex]
    @referent = handlerclass.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @referent }
    end
  end

  # Get a new referent based on the given tag id
  # GET /referents/new
  # GET /referents/new.json?tagid=1&mode={over,before,after}&parent=referentid
  def new
      @tabindex = session[:tabindex] || params[:tabindex] || 0
      handlerclass = @@HandlersByIndex[@tabindex]
    @referent = handlerclass.new
    @referent.express (params[:tagid]) if params[:tagid]

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: [{ :title=>@referent.longname, :isLazy=>true, :key=>@referent.id, :isFolder=>!@referent.leaf? }] }
    end
  end

  # GET /referents/1/edit
  def edit
      @tabindex = session[:tabindex] || params[:tabindex] || 0
      handlerclass = @@HandlersByIndex[@tabindex]
    @referent = handlerclass.find(params[:id])
  end

  # POST /referents?tagid=1&mode={over,before,after}&target=referentid
  # POST /referents.json?tagid=1&mode={over,before,after}&target=referentid
  def create
    @tabindex = session[:tabindex] || params[:tabindex] || 0
    handlerclass = @@HandlersByIndex[@tabindex]
    tagid = params[:tagid].to_i
    keyback = 0
    if params[:mode] == "over"
        # "over" indicates to add the tag to the referent's expressions
        @referent = handlerclass.find params[:target].to_i
        @referent.express tagid
    else
        targetid = params[:target] ? params[:target].to_i : 0
        parentid = (targetid > 0) ? handlerclass.find(targetid).parent_id : 0
        @referent = handlerclass.create :parent_id=>parentid 
        @referent.express tagid, :canonical
        keyback = @referent.id
    end

    respond_to do |format|
      if @referent && @referent.save
        format.html { redirect_to @referent, notice: 'Referent was successfully created/aliased.' }
        format.json { render json: [{ :title=>@referent.longname, :isLazy=>true, :key=>keyback, :isFolder=>!@referent.leaf? }], status: :created }
      else
        format.html { render action: "new" }
        format.json { render json: @referent.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /referents/1
  # PUT /referents/1.json
  def update
      @tabindex = session[:tabindex] || params[:tabindex] || 0
      handlerclass = @@HandlersByIndex[@tabindex]
    @referent = handlerclass.find(params[:id])
    respond_to do |format|
      if @referent.update_attributes(params[:referent])
        format.html { redirect_to @referent, notice: 'Referent was successfully updated.' }
        format.json { render json: [], status: :success }
      else
        format.html { render action: "edit" }
        format.json { render json: @referent.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /referents/1
  # DELETE /referents/1.json
  def destroy
      @tabindex = session[:tabindex] || params[:tabindex] || 0
      handlerclass = @@HandlersByIndex[@tabindex]
    @referent = handlerclass.find(params[:id])
    @referent.destroy

    respond_to do |format|
      format.html { redirect_to referents_url }
      format.json { head :ok }
    end
  end
  
  # /referents/connect?parent=&child=
  def add_child
      @tabindex = session[:tabindex] || params[:tabindex] || 0
      handlerclass = @@HandlersByIndex[@tabindex]
      parent = handlerclass.find params[:parentid].to_i
      child = handlerclass.find params[:childid].to_i
      parent.add_child child
  end
end
