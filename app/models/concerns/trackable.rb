# Tracking of attributes.                                                                                   flags
# Each tracked attribute has 2 boolean fields embedded in the :attr_tracking attribute:
# <attr>_needed indicates an unfulfilled need for the value
# <attr>_ready indicates that the value has been finalized
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
      has_flags flags.merge(:column => 'attr_trackers')
      @@TRACKED_ATTRIBUTES = list
      # Now FlagShihTzu will provide a _needed and a _ready bit for each tracked attribute
      # By default, an attribute is neither needed nor ready
    end

    # List out the tracked attributes by examining the tracking bits
    def tracked_attributes
      @@TRACKED_ATTRIBUTES
    end

  end

  def self.included(base)
    base.extend(ClassMethods)
  end

  def accept_attribute attrname, value
    attrname = attrname.to_s
    self.send (attrname+'=').to_sym, value
    if all_attr_trackers.include?((attrname+'_needed').to_sym)
      # This attribute is tracked => clear 'needs' bit and set the 'ready' bit
      self.send (attrname+'_needed=').to_sym, false
      self.send (attrname+'_ready=').to_sym, true
    end
  end

  # Call accept_attribute for each key-value pair in the hash
  def accept_attributes attribs={}
    attribs.each { |value, attrib| accept_attribute attrib, value}
  end

  # Handle tracking-related calls. The form is 'attrname_verb', where
  # * attrname is the name of an attribute, possibly but not necessarily tracked
  # * verb indicates what to do with the attribute, i.e.
  #   -- 'accept' means to assign the attribute, clear the associated 'needs' bit and set the 'ready' bit
  #   -- 'if_ready' is for reporting a value. If the corresponding 'ready' bit is true, invoke the passed block with the attribute value
  def method_missing namesym, *args
    if match = namesym.to_s.match(/(.*)_(accept|if_ready)$/)
      attrname, verb = match[1..2]
      case verb
      when 'accept'
        accept_attribute attrname, args.first
        return
      when 'if_ready'
        # Call the provided block with the named attribute value iff the corresponding 'ready' bit is on
        if self.send((attrname+'_ready').to_sym)
          args[0].call(self.send attrname.to_sym)
        end
      end
      return
    end
    super(namesym, *args) if defined(super)
  end

  # Force launching if any attribute is needed
  def bkg_launch force=false
    super(force || attrib_needed?) if defined?(super)
  end

  # Notify the object of a need for certain derived values. They may be derived immediately or in background.
  def request_attributes *list_of_attributes, &block
    newly_needed = assert_needed_attributes(*list_of_attributes)
    return if newly_needed.empty?
    block.call *newly_needed if block_given?
    bkg_launch true
  end

  # Do your best to ensure that the given values are present
  def ensure_attributes *list_of_attributes, &block
    if block_given?
      request_attributes *list_of_attributes, block
    else
      request_attributes *list_of_attributes
    end
    bkg_land
  end

  # Report on the 'needed' bit for the named attribute. If no attribute specified, report whether ANY attribute is needed
  def attrib_needed? attrib_sym=nil
    return send(:"#{attrib_sym}_needed") if attrib_sym
    selected_attr_trackers.any? { |attrib_sym| attrib_sym.to_s.match(/_needed/) && send(attrib_sym) }
  end

  # Set the 'needed' bit for the attribute and return the attribute_sym iff wasn't needed before
  def attrib_needed! attrib_sym
    unless attrib_needed?(attrib_sym)
      send :"#{attrib_sym}_needed=", true
      attrib_sym
    end
  end

  # Report on the 'ready' bit for the named attribute
  def attrib_ready? attrib_sym
    send :"#{attrib_sym}_ready"
  end

  # Set the 'ready' bit for the attribute and return the attribute_sym iff wasn't ready before
  def attrib_ready! attrib_sym
    unless attrib_ready?(attrib_sym)
      send :"#{attrib_sym}_ready=", true
      attrib_sym
    end
  end

  # Ensure that all of the given attributes are marked as needed UNLESS they're already ready or needed
  def assert_needed_attributes *list_of_attributes
    list_of_attributes.collect { |attrib|
      attrib_needed!(attrib) unless attrib_ready?(attrib) || attrib_needed?(attrib)
    }.compact
  end

  # Which of the specified attributes haven't been declared as needed before now?
  def newly_needed *list_of_attributes
    (list_of_attributes - ready_attributes) - needed_attributes
  end

  # What attributes are now good?
  def ready_attributes
    selected_attr_trackers.collect { |ready_or_needed| ready_or_needed.to_s.match /(.*)_ready$/ ; $1&.to_sym }.compact
  end

  def ready_attribute_values
    Hash[ *ready_attributes.collect{ |attrname| [ attrname, send(attrname) ]}.flatten ]
  end

  # What attributes are now needed?
  def needed_attributes
    selected_attr_trackers.collect { |ready_or_needed| ready_or_needed.to_s.match /(.*)_needed$/ ; $1&.to_sym }.compact
  end
end

