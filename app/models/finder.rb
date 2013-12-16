class Finder < ActiveRecord::Base
  attr_accessible :finds, :selector, :read_attrib
  has_and_belongs_to_many :sites
end
