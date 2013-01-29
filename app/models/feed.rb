require 'rss'
require 'open-uri'

class Feed < ActiveRecord::Base
  attr_accessible :description, :site_id, :feedtype, :approved, :url
  
  belongs_to :site
  
  def validate
    valid = true
    begin
      open(url) do |rss|
        feed = RSS::Parser.parse(rss)
        self.description = feed.channel.title
        valid = save
      end
    rescue Exception => e
      valid = false
    end
    valid
  end
  
  def items
    @items = []
    open(url) do |rss|
      feed = RSS::Parser.parse(rss)
      @items = feed.items
    end
    @items
  end
  
  def show
    items.each do |item|
      puts "Item: <a href='#{item.link}'>#{item.title}</a>"
      puts "Published on: #{item.date}"
      puts "#{item.description}"
      debugger
    end
=begin
    open(url) do |rss|
      feed = RSS::Parser.parse(rss)
      puts "Title: #{feed.channel.title}"
      feed.items.each do |item|
        puts "Item: <a href='#{item.link}'>#{item.title}</a>"
        puts "Published on: #{item.date}"
        puts "#{item.description}"
        debugger
      end
=end
    nil
  end
  
  @@feedtypes = [
    [:Misc, 0], 
    [:Recipes, 1], 
    [:Tips, 2]
  ]
  
  @@feedtypenames = []
  @@feedtypes.each { |feedtype| @@feedtypenames[feedtype[1]] = feedtype[0] }

  # return an array of status/value pairs for passing to select()
  def self.feedtype_selection
    @@feedtypes
  end
  
  def feedtypename
    @@feedtypenames[feedtype]
  end
  
end
