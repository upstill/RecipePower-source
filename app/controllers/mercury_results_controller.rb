class MercuryResultsController < CollectibleController
  before_action :set_mercury_result, only: [:show, :edit, :update, :destroy]

  def set_mercury_result
    @mercury_result = MercuryResult.find params[:id]
  end
  
end