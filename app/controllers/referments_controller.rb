class RefermentsController < ApplicationController

  # Creating a Referment is quite flexible. The url may denote a Referrable object internal to RecipePower, or any
  # external URL.
  def create
    @referment = RefermentServices.assert params[:referment][:kind], params[:referment][:url]
    if @referment.errors.any?
      resource_errors_to_flash @referment
    else
      # @referment.bkg_land
      update_and_decorate @referment
    end
    respond_to do |format|
      format.json {
        if @referment.errors.any?
          render 'application/errors'
        else
          render json: @referment.attributes.slice( 'id', 'url', 'kind', 'title' )
        end
      }
      format.html { }
    end
  end

  def update
  end

  def destroy
  end
end
