class TagsetsController < ApplicationController
  before_action :set_tagset, only: [:show, :edit, :update, :destroy]

  # GET /tagsets
  def index
    @tagsets = Tagset.all
  end

  # GET /tagsets/1
  def show
  end

  # GET /tagsets/new
  def new
    update_and_decorate Tagset.new
  end

  # GET /tagsets/1/edit
  def edit
  end

  # POST /tagsets
  def create
    @tagset = Tagset.create tagset_params
    if @tagset.save
      redirect_to @tagset, notice: 'Tagset was successfully created.'
    else
      render :new
    end
  end

  # PATCH/PUT /tagsets/1
  def update
    if update_and_decorate
      redirect_to @tagset, notice: 'Tagset was successfully updated.'
    else
      render :edit
    end
  end

  # DELETE /tagsets/1
  def destroy
    @tagset.destroy
    redirect_to tagsets_url, notice: 'Tagset was successfully destroyed.'
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_tagset
    @tagset = Tagset.find params[:id]
  end

  # Only allow a trusted parameter "white list" through.
  def tagset_params
    params.require(:tagset).permit :title, :tagtype
  end
end
