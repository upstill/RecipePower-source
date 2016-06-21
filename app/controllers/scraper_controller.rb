class ScraperController < ApplicationController
  def new
    @scraper = Scraper.new recur: false
  end

  def create
    @scraper = Scraper.assert params[:scraper][:url], (params[:scraper][:recur] == '1')
    @scraper.perform_naked
    if resource_errors_to_flash @scraper
      smartrender :action => :new
    else
      render json: { done: true, alert: 'Scraping successful' }
    end
  end
end
