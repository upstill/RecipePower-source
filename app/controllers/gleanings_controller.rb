class GleaningsController < CollectibleController
  before_action :set_gleaning, only: [:show, :edit, :update, :destroy]

  def set_gleaning
    @gleaning = Gleaning.find params[:id]
  end
end
