class RatingsController < ApplicationController
  before_action :set_rating, only: [:show, :edit, :update, :destroy]

  # GET /ratings
  # GET /ratings.xml
  def index
    @ratings = Rating.all

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @ratings }
    end
  end

  # GET /ratings/1
  # GET /ratings/1.xml
  def show
    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @rating }
    end
  end

  # GET /ratings/new
  # GET /ratings/new.xml
  def new
    @rating = Rating.new
    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @rating }
    end
  end

  # GET /ratings/1/edit
  def edit
  end

  # POST /ratings
  # POST /ratings.xml
  def create
    @rating = Rating.new rating_params.merge(user_id: current_user.id)

    respond_to do |format|
      if @rating.save
        format.html { redirect_to(@rating, :notice => 'Rating was successfully created.') }
        format.xml  { render :xml => @rating, :status => :created, :location => @rating }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @rating.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /ratings/1
  # PUT /ratings/1.xml
  def update
    respond_to do |format|
      if @rating.update_attributes rating_params
        format.html { redirect_to(@rating, :notice => 'Rating was successfully updated.') }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @rating.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /ratings/1
  # DELETE /ratings/1.xml
  def destroy
    @rating.destroy

    respond_to do |format|
      format.html { redirect_to(ratings_url) }
      format.xml  { head :ok }
    end
  end

  private

  def set_rating
    @rating = Rating.find params[:id]
  end

  def rating_params
    params.require(:rating).permit :recipe_id, :scale_id, :scale_val
  end
end
