class ImageReferencesController < ApplicationController
  before_action :set_image_reference, only: [:show, :edit, :update, :destroy]
  # GET /image_references
  # GET /image_references.json

  def index
    # seeker_result Tag, 'div.tag_list' # , clear_tags: true
    smartrender 
  end

  # GET /image_references/1
  # GET /image_references/1.json
  def show
    smartrender
  end

  # GET /image_references/new
  # GET /image_references/new.json
  def new
    @image_reference = ImageReference.new
    smartrender
  end

  # GET /image_references/1/edit
  def edit
    smartrender
  end

  # POST /image_references
  # POST /image_references.json
  def create
    @image_reference = ImageReferenceServices.find_or_initialize params[:image_reference][:url]
    notice = "Image was successfully #{@image_reference.persisted? ? 'fetched' : 'created'}."
    respond_to do |format|
      if @image_reference.save
        format.html { redirect_to @image_reference, notice: notice }
        format.json { render json: @image_reference, status: :created, location: @image_reference }
      else
        format.html { render action: 'new' }
        format.json { render json: @image_reference.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /image_references/1
  # PUT /image_references/1.json
  def update
    respond_to do |format|
      if @image_reference.update_attributes image_reference_params
        format.html { redirect_to @image_reference, notice: 'Image was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @image_reference.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /image_references/1
  # DELETE /image_references/1.json
  def destroy
    @image_reference.destroy
    respond_to do |format|
      format.html { redirect_to image_references_url }
      format.json { head :no_content }
    end
  end

  private

  def set_image_reference
    @image_reference = ImageReference.find params[:id]
  end

  def image_reference_params
    params.require(:image_reference).permit # Permit nothing (for now)
    # :url, :type, :thumbdata, :errcode, :canonical, :host, :status, :filename, :link_text, :dj_id
  end

end
