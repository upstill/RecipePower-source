class FeedEntriesController < ApplicationController
  def collect
    @user = current_user
    @feed_entry = FeedEntry.find params[:id]
    @user.touch @feed_entry, true
    @feed_entry.prep_params @user.id
    redirect_to :edit
  end

  def edit
    fe = FeedEntry.find params[:id]
    @templateer = Templateer.new fe, current_user.id
  end

  def update
    fe = FeedEntry.find params[:id]
    fe.update_attributes params[:feed_entry]
    fe.accept_params
    fe.save
    if fe.errors.empty?
      @popup_msg = "Feed Entry is saved"
      render :ack_popup
    else
      @templateer = Templateer.new fe, current_user.id
      render :action => 'edit', :notice => "Huhh??!?"
    end
  end
end
