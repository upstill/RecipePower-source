# Class for presenting one part of the notifications panel
require 'ostruct'
class NotifsSection < OpenStruct
  attr_accessor :is_main, # Label in title bar is prominent when the panel is closed
                :is_vis, # Open by default (only one allowed)
                :exclusive, # Alert-style: no other titles when visible
                :title, # Label for the title bar
                :partial, # Name of the partial it renders into the panel
                :partial_locals # Local variables for the partial

end
