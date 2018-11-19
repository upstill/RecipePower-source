class RefermentsController < ApplicationController
  before_action :set_referment, only: [:show, :edit, :update, :destroy]

  # Creating a Referment is quite flexible. The url may denote a Referrable object internal to RecipePower, or any
  # external URL. As of this writing, it only occurs in the course of editing a referent
  def create
    rfmp = referment_params
    @referent = Referent.find_by id: rfmp[:referent_id]
    @referment = ReferentServices.new(@referent).assert_referment rfmp[:kind], rfmp[:url]
    @referment.referee.bkg_land if @referment.referee.is_a?(Backgroundable) && !@referment.errors.any? # Scrape title from the page_ref
    respond_to do |format|
      format.json {
        if @referment.errors.any?
          render json: view_context.flash_notify(@referment, false)
        else
          render json: @referment.attributes.slice( 'id', 'referee_type', 'referee_id').
                     merge(url: @referment.url, title: @referment.title, kind: @referment.kind)
        end
      }
      format.html { }
    end
  end

  def update
  end

  def destroy
  end

private

  def set_referment
    @referment = Referment.find_by id: params[:id]
  end

  def referment_params
    params.require(:referment).permit :kind, :url, :title, :referent_id
  end
end
