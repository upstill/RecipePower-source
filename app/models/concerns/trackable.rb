# Tracking of attributes.                                                                                   flags
# Each tracked attribute has 2 boolean fields embedded in the :attr_tracking attribute:
# <attr>_needed indicates an unfulfilled need for the value
# <attr>_ready indicates that the value has been finalized
include FlagShihTzu  # https://github.com/pboling/flag_shih_tzu
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
      tracked_attributes = list
      self.tracked_attributes = list
      # Now FlagShihTzu will provide a _needed and a _ready bit for each tracked attribute
      # By default, an attribute is neither needed nor ready
    end

    # List out the tracked attributes by examining the tracking bits
    def tracked_attributes
      @tracked_attributes || []
    end

    def tracked_attributes= list
      @tracked_attributes = list
    end

  end

  def self.included(base)
    base.extend(ClassMethods)
  end

  # Set and accept the attribute. Action depends on the 'ready' and 'needed' bits
  # !ready, !needed => set
  # !ready, needed => set
  # ready, !needed => ignore
  # ready, needed => set
  # In other words, if a value has been accepted and not previously invalidated, leave it alone.
  # ** the 'force' flag sets the attribute whether or not it's needed or accepted
  def accept_attribute attrname, value, force=false
    attrname = attrname.to_s
    return if attrib_ready?(attrname) && !(attrib_needed?(attrname) || force)
    if block_given?
      # For any side-effects as a result of changing the attribute, call the block
      previous = self.send attrname.to_sym
      self.send (attrname+'=').to_sym, value
      # NB: it's possible that the accepted value is NOT the same as the provided value, so we compare
      # changes on the attribute.
      yield value if self.send(attrname.to_sym) != previous
    else  # No block? Just set the value
      self.send (attrname+'=').to_sym, value
    end
    if all_attr_trackers.include?((attrname+'_needed').to_sym)
      # This attribute is tracked => clear 'needed' bit and set the 'ready' bit
      self.send (attrname+'_needed=').to_sym, false
      self.send (attrname+'_ready=').to_sym, true
    end
  end

  # Call attribute setter or accept_attribute for each key-value pair in the hash
  def accept_attributes attribs={}
    attribs.slice(*self.class.tracked_attributes).each do |attrib, value|
      setter = :"accept_#{attrib}"
      respond_to?(setter) ? self.send(setter, value) : accept_attribute(attrib, value)
    end
  end

  def clear_needed_attributes
    needed_attributes.each { |attr_name| attrib_needed! attr_name, false }
  end

  # Handle tracking-related calls. The form is 'attrname_verb', where
  # * attrname is the name of an attribute, possibly but not necessarily tracked
  # * verb indicates what to do with the attribute, i.e.
  #   -- 'accept' means to assign the attribute, clear the associated 'needed' bit and set the 'ready' bit
  #   -- 'if_ready' is for reporting a value. If the corresponding 'ready' bit is true, invoke the passed block with the attribute value
  def method_missing namesym, *args
    if match = namesym.to_s.match(/(.*)_(accept|if_ready)$/)
      attrname, verb = match[1..2]
      case verb
      when 'accept'
        accept_attribute attrname, args.first
      when 'if_ready'
        # Provide
        return attrib_ready?(attrname) ? self.send(attrname.to_sym) : args.first
      end
      return
    end
    super(namesym, *args) if defined?(super)
  end

  # Invalidate the attribute(s), triggering the request process.
  # In the absence of attribute arguments, defaults to ALL tracked attributes.
  # The syntax is a (possibly empty) list of attributes to refresh, possibly followed by a hash of flags:
  # :except provides a list of attributes NOT to refresh
  # :immediate if true, forces the attribute(s) to update before returning
  # An empty list before the argument hash causes ALL tracked attributes to be refreshed
  def refresh_attributes *args, except: [], immediate: false
    # No args => update all tracked attributes
    attrs = args.present? ? args.map(&:to_sym) : self.class.tracked_attributes
    attrs -= except.map(&:to_sym)
    # Invalidate all given attributes
    attribs_ready! attrs, false
    if immediate
      ensure_attributes *attrs
    else
      request_attributes *attrs
    end
  end

  def ensure_attributes *list_of_attributes
    request_attributes *list_of_attributes
    bkg_land
    adopt_dependencies
  end

  # Notify the object of a need for certain derived values. They may be derived immediately or in background.
  def request_attributes *list_of_attributes
    assert_needed_attributes *list_of_attributes
    logger.info "Requesting attributes #{needed_attributes} of #{self} ##{id}"
    request_dependencies # Launch all objects that we depend on
    bkg_launch attrib_needed?
  end

  # Stub to be overridden for an object to launch prerequisites to needed attributes
  def request_dependencies
  end

  # Once the entities we depend on have settled, we take on their values
  def adopt_dependencies
    super if defined? super
  end

  # Report on the 'needed' bit for the named attribute.
  # If no attribute specified, report whether ANY attribute is needed
  def attrib_needed? attrib_sym = nil
    attrib_sym.nil? ? needed_attributes.present? : send(:"#{attrib_sym}_needed")
  end

  # Report on the 'ready' bit for the named attribute
  def attrib_ready? attrib_sym
    send :"#{attrib_sym}_ready"
  end

  # Set the 'ready' bit for the attribute and return the attribute_sym iff wasn't ready before
  def attrib_ready! attrib_sym, ready_now=true
    unless attrib_ready?(attrib_sym) == ready_now
      send :"#{attrib_sym}_ready=", ready_now
      attrib_sym
    end
  end

  # What attributes are now good?
  def ready_attributes
    selected_attr_trackers.collect { |ready_or_needed| ready_or_needed.to_s.match /(.*)_ready$/ ; $1&.to_sym }.compact
  end

  def ready_attribute_values
    Hash[ *ready_attributes.collect{ |attrname| [ attrname, send(attrname) ]}.flatten(1) ]
  end

  # What attributes are currently needed?
  def needed_attributes
    selected_attr_trackers.collect { |ready_or_needed| ready_or_needed.to_s.match /(.*)_needed$/ ; $1&.to_sym }.compact
  end

  private

  # Convenience methods, for internal use only

  def attribs_needed! attrib_syms, needed_now=true
    attrib_syms.each { |attrib_sym| attrib_needed! attrib_sym, needed_now }
  end

  def attribs_ready! attrib_syms, ready_now=true
    attrib_syms.each { |attrib_sym| attrib_ready! attrib_sym, ready_now }
  end

  # Set the 'needed' bit for the attribute and return the attribute_sym iff wasn't needed before
  def attrib_needed! attrib_sym, needed_now=true
    unless attrib_needed?(attrib_sym) == needed_now
      send :"#{attrib_sym}_needed=", needed_now
      attrib_sym
    end
  end

  # Ensure that all of the given attributes are marked as needed UNLESS they're already ready or needed
  # RETURN the list of attributes needed now that weren't needed previously
  def assert_needed_attributes *list_of_attributes
    list_of_attributes.collect { |attrib|
      attrib_needed!(attrib) unless attrib_ready?(attrib) || attrib_needed?(attrib)
    }.compact
  end

end

