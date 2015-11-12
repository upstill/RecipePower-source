class SearchController < ApplicationController
  def index
    @no_pagelet_search = true
    smartrender
  end
end
