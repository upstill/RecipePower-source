class Finder < ActiveRecord::Base
  attr_accessible :finds, :selector, :read_attrib
  belongs_to :site
end
