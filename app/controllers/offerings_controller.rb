class OfferingsController < ApplicationController
  before_action :set_offering, only: [:show, :edit, :update, :destroy]

  # GET /offerings
  def index
    @offerings = Offering.all
  end

  # GET /offerings/1
  def show
  end

  # GET /offerings/new
  def new
    @offering = Offering.new
  end

  # GET /offerings/1/edit
  def edit
  end

  # POST /offerings
  def create
    @offering = Offering.new(offering_params)

    if @offering.save
      redirect_to @offering, notice: 'Offering was successfully created.'
    else
      render :new
    end
  end

  # PATCH/PUT /offerings/1
  def update
    if @offering.update(offering_params)
      redirect_to @offering, notice: 'Offering was successfully updated.'
    else
      render :edit
    end
  end

  # DELETE /offerings/1
  def destroy
    @offering.destroy
    redirect_to offerings_url, notice: 'Offering was successfully destroyed.'
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_offering
      @offering = Offering.find(params[:id])
    end

    # Only allow a trusted parameter "white list" through.
    def offering_params
      params.require(:offering).permit(:product_id, :page_ref_id)
    end
end
