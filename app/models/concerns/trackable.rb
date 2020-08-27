# Tracking of attributes.
# Each tracked attribute has 2 boolean fields embedded in the :attr_tracking attribute
#
include FlagShihTzu
module Trackable
  extend ActiveSupport::Concern

  module ClassMethods

    # Declare a set of attributes that will be tracked
    def attr_trackable *list
      flags = {}
      list.collect { |attrib| [ "#{attrib.to_s}_needed", "#{attrib.to_s}_ready" ] }.
          flatten.
          map(&:to_sym).
          each_with_index { |val, ix| flags[ix+1] = val }
      has_flags flags.merge(:column => 'attr_tracking')
      # Now FlagShihTzu will provide a _needed and a _ready bit for each tracked attribute
      # By default, an attribute is neither needed nor ready
    end

  end

  def self.included(base)
    base.extend(ClassMethods)
  end

end

