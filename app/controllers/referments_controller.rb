class RefermentsController < ApplicationController

  # Creating a Referment is quite flexible. The url may denote a Referrable object internal to RecipePower, or any
  # external URL.
  def create
    @referment = RefermentServices.assert params[:referment][:kind], params[:referment][:url]
    if @referment.errors.any?
      resource_errors_to_flash @referment
    else
      @referment.referee.bkg_land # Scrape title from the page_ref
      # update_and_decorate @referment
    end
    respond_to do |format|
      format.json {
        if @referment.errors.any?
          render 'application/errors'
        else
          render json: @referment.attributes.slice( 'id', 'referee_type', 'referee_id' ).
                     merge(@referment.referee.attributes.slice 'url', 'title').merge(kind: 'article')
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
