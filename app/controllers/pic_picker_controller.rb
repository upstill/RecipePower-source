class PicPickerController < ApplicationController
  def new
    # Expecting params as follows:
    partial = render_to_string partial: "pic_picker",
           locals: {
               picurl: params[:picurl], # @site.logo,
               pageurl: params[:pageurl], # @site.sampleURL,
               id: params[:entity_id] # @site.id
           }
    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: { dlog: partial } }
    end
  end
end