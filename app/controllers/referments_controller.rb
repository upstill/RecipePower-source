class RefermentsController < ApplicationController

  # Creating a Referment is quite flexible. The url may denote a Referrable object internal to RecipePower, or any
  # external URL.
  def create
    @referent = Referent.find_by id: params[:referment][:referent_id]
    @referment = ReferentServices.new(@referent).assert_referment params[:referment][:kind], params[:referment][:url]
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

  def referment_params
    params.permit(:kind, :url, :title)
  end
end
