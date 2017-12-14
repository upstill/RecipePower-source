class ScraperController < ApplicationController
  before_filter :login_required

  def new
    @scraper = Scraper.new recur: true
  end

  def create
    @scraper = Scraper.assert params[:scraper][:url], (params[:scraper][:recur] == 'true')
    if params[:scraper][:immediate] == 'true'
      @scraper.bkg_land true
      if resource_errors_to_flash @scraper
        smartrender :action => :new
      else
        @scraper.save
        render json: { done: true, alert: 'Scraping successful' }
      end
    else
      @scraper.bkg_launch true
      render json: { done: true, alert: msg }
    end
  end

  # Reset the database in preparation for scraping
  def init
    if !response_service.admin_view?
      render json: { popup: 'Must be an admin to initialize the database!!' }
    elsif Rails.env.production?
      render json: { popup: 'Can\'t initialize the production database!!' }
    else
      Answer.delete_all
      Authentication.delete_all
      Expression.delete_all
      Finder.delete_all
      List.delete_all
      Rcpref.delete_all
      Recipe.delete_all
      Reference.delete_all
      Referent.delete_all
      Referment.delete_all
      ReferentRelation.delete_all
      ResultsCache.delete_all
      Scraper.clear_all
      Site.delete_all
      TagSelection.delete_all
      Tag.delete_all
      TagOwner.delete_all
      Tagging.delete_all
      TagsCache.delete_all
      Tagset.delete_all
      # User.delete_all
      # UserRelation.delete_all
      Vote.delete_all
      sql = 'DELETE FROM delayed_jobs;'
      ActiveRecord::Base.connection.execute(sql)
      render json: { popup: 'Database is initialized and ready for scraping.' }
    end
  end
end
