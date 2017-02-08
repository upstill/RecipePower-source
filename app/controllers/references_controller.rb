class ReferencesController < ApplicationController
  # GET /references
  # GET /references.json

  def index
    # seeker_result Tag, 'div.tag_list' # , clear_tags: true
    smartrender 
  end

  # GET /references/1
  # GET /references/1.json
  def show
    @reference = Reference.find(params[:id])
    smartrender
  end

  # GET /references/new
  # GET /references/new.json
  def new
    @reference = Reference.new
    smartrender
  end

  # GET /references/1/edit
  def edit
    @reference = Reference.find(params[:id])
    smartrender
  end

  # POST /references
  # POST /references.json
  def create
    @reference = Reference.new(params[:reference])

    respond_to do |format|
      if @reference.save
        format.html { redirect_to @reference, notice: 'Reference was successfully created.' }
        format.json { render json: @reference, status: :created, location: @reference }
      else
        format.html { render action: "new" }
        format.json { render json: @reference.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /references/1
  # PUT /references/1.json
  def update
    @reference = Reference.find(params[:id])

    respond_to do |format|
      if @reference.update_attributes(params[:reference])
        format.html { redirect_to @reference, notice: 'Reference was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @reference.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /references/1
  # DELETE /references/1.json
  def destroy
    @reference = Reference.find(params[:id])
    @reference.destroy

    respond_to do |format|
      format.html { redirect_to references_url }
      format.json { head :no_content }
    end
  end

end
