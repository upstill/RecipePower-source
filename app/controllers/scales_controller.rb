class ScalesController < ApplicationController
  before_action :set_scale, only: [:show, :edit, :update, :destroy]
  # GET /scales
  # GET /scales.xml
  def index
    @scales = Scale.all
    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @scales }
    end
  end

  # GET /scales/1
  # GET /scales/1.xml
  def show
    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @scale }
    end
  end

  # GET /scales/new
  # GET /scales/new.xml
  def new
    @scale = Scale.new
    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @scale }
    end
  end

  # GET /scales/1/edit
  def edit
  end

  # POST /scales
  # POST /scales.xml
  def create
    @scale = Scale.new scale_params.merge user_id: current_user.id
    respond_to do |format|
      if @scale.save
        format.html { redirect_to(@scale, :notice => 'Scale was successfully created.') }
        format.xml  { render :xml => @scale, :status => :created, :location => @scale }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @scale.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /scales/1
  # PUT /scales/1.xml
  def update
    respond_to do |format|
      if @scale.update_attributes scale_params # Can't change the user_id once created
        format.html { redirect_to(@scale, :notice => 'Scale was successfully updated.') }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @scale.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /scales/1
  # DELETE /scales/1.xml
  def destroy
    @scale.destroy
    respond_to do |format|
      format.html { redirect_to scales_url }
      format.xml  { head :ok }
    end
  end

  private

  def set_scale
    @scale = Scale.find params[:id]
  end

  def scale_params
    params.require(:scale).permit :minval, :maxval, :minlabel, :maxlabel, :name
  end
end
