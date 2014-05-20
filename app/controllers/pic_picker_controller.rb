class PicPickerController < ApplicationController
  def new
    # Expecting params as follows:
    partial = render_to_string partial: "pic_picker",
           locals: {
               picurl: params[:picurl], 
               pageurl: params[:pageurl],
               golinkid: params[:golinkid]
           }
    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: { dlog: partial } }
    end
  end
end
