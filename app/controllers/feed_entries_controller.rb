class FeedEntriesController < ApplicationController
  def collect
    update_and_decorate # Generate a FeedEntryDecorator as @feed_entry and prepares it for editing
    current_user.collect @feed_entry if current_user
    redirect_to :edit
  end

  def edit
    fe = FeedEntry.find params[:id]
    @templateer = Templateer.new fe, current_user.id
  end

  def update
    update_and_decorate nil, params[:feed_entry]
    if fe.errors.empty? && fe.save
      @popup_msg = "Feed Entry is saved"
      render :ack_popup
    else
      @templateer = Templateer.new fe, current_user.id
      render :action => 'edit', :notice => "Huhh??!?"
    end
  end
end
