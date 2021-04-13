# Tracking of attributes.                                                                                   flags
# Each tracked attribute has 2 boolean fields embedded in the :attr_tracking attribute:
# <attr>_needed indicates an unfulfilled need for the value
# <attr>_ready indicates that the value has been accepted
include FlagShihTzu  # https://github.com/pboling/flag_shih_tzu
module Trackable
  extend ActiveSupport::Concern

  included do
    # before_save :request_for_background
    before_save do |entity|
      # When first saved, we establish needed attributes for background processing
      entity.request_for_background if !entity.persisted?
    end

    after_save do |entity|
      entity.request_attributes  # (re)Launch dj as necessary
    end
  end

  module ClassMethods
# Declare a set of attributes that will be tracked
    def attr_trackable *list
      flags = {}
      list.collect { |attrib| [ "#{attrib.to_s}_needed", "#{attrib.to_s}_ready" ] }.
          flatten.
          map(&:to_sym).
          each_with_index { |val, ix| flags[ix+1] = val }
      has_flags flags.merge(:column => 'attr_trackers')
      @tracked_attributes = list
      @tracked_attributes.freeze
      # Now FlagShihTzu will provide a _needed and a _ready bit for each tracked attribute
      # By default, an attribute is neither needed nor ready

      # For each tracked attribute, we define:
      # -- an override of the getter method which attempts to ensure that the attribute is ready
      # -- an override of the setter method which also sets the ready bit
      # -- aliases for the existing getter and setter methods to call them directly, for the use of this module
      self.instance_eval do
        # URL, PageRef -> PageRef
        # Assign the URL to be used in accessing the entity. In the case of a successful redirect, this <may>
        # be different from the one provided
        list.each do |attrname|
          setter = :"#{attrname}="
          osetter = :"o_tkbl_#{attrname}_eq"
          alias_method osetter, setter if public_instance_methods.include?(setter)
          define_method setter do |val|
            if Rails.env.development?
              printable = val.is_a?(String) ? "'#{val.truncate 100}'" : val.to_s
              logger.debug "#{self.class} writing #{printable} to #{attrname}"
            end
            # Clear 'needed' bit and set the 'ready' bit
            attrib_done attrname
            if defined?(super)
              super(val)
            elsif self.respond_to? osetter
              self.send osetter, val
            else
              x=2
            end
            # self.call :"o_tkbl_#{attrname}_eq", val
          end

=begin    Hell, just use the default reader
          define_method "#{attrname}" do
            logger.debug "#{self.class} reading #{attrname}"
            super()
          end
=end
        end
      end
    end

    def tracked_attributes
      @tracked_attributes || []
    end

  end

  def self.included(base)
    base.extend(ClassMethods)
  end

  # Should be overridden by any Trackable model to request attributes to be generated in background
  # when entity is first saved
  def request_for_background

  end

  # Set and accept the attribute. Action depends on the 'ready' and 'needed' bits
  # !ready, !needed => set
  # !ready, needed => set
  # ready, !needed => ignore
  # ready, needed => set
  # In other words, if a value has been accepted and not previously invalidated, leave it alone.
  # ** the 'force' flag sets the attribute whether or not it's needed or accepted
  # In the case of an untracked attribute, the effect should be identical to simple assignment
  def accept_attribute attrname, value, force=false
    setter = :"#{attrname}="
    tracked = self.class.tracked_attributes.include? attrname.to_sym
    # Basic policy: attributes values "stick" unless priorly invalidated by 'need'ing them
    return if tracked &&
        (attrib_ready?(attrname) && !(force || attrib_needed?(attrname))) # ...and that it's open to change
    # Now assign the attribute as usual, calling any provided block if the value has changed
    if block_given?
      # For any side-effects as a result of changing the attribute, call the block
      previous = self.send attrname.to_sym
      rtnval = self.send setter, value
      # NB: it's possible that the accepted value is NOT the same as the provided value, so we compare
      # changes on the attribute.
      yield value if self.send(attrname.to_sym) != previous
    else  # No block? Just set the value
      rtnval = self.send setter, value
    end
    attrib_done attrname if tracked
    rtnval
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
    if match = namesym.to_s.match(/(.*)_(accept|if_ready|open\?)$/)
      attrname, verb = match[1..2]
      case verb
      when 'open?'
        !attrib_ready?(attrname) || attrib_need?(attrname)
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
    attrs = self.class.tracked_attributes
    attrs &= args.map(&:to_sym) if args.present? # Slyly eliding invalid attributes
    attrs -= except.map(&:to_sym)
    # Invalidate all given attributes
    attribs_ready! attrs, false
    if immediate
      ensure_attributes *attrs
    else
      request_attributes *attrs
    end
  end

  # Ensure that the given attributes have been acquired if at all possible.
  # Calling ensure_attributes with no arguments means that all needed attributes should be acquired
  # NB: needed attributes other than those specified may be acquired as a side effect
  def ensure_attributes *list_of_attributes
    if list_of_attributes.present?
      request_attributes *list_of_attributes
    else
      list_of_attributes = needed_attributes
    end
    # Try to acquire attributes from their dependencies without landing
    adopt_dependencies
    # If any attributes are still needed, call them in via background job
    bkg_land if (list_of_attributes & needed_attributes).present?
  end

  # A Trackable winds up its (successful) work by taking any attributes from its dependencies
  def success job=nil
    super(job) if defined?(super)
    adopt_dependencies
  end

  # Notify the object of a need for certain derived values. They may be derived immediately or in background.
  def request_attributes *list_of_attributes, force: false
    list_of_attributes.each { |attrib|
      attrib_needed!(attrib) if !(attrib_ready?(attrib) || attrib_needed?(attrib)) || force
    }
    request_dependencies # Launch all objects that we depend on
    if attrib_needed?
      logger.debug "Requesting attributes #{needed_attributes} of #{self} ##{id}"
      bkg_launch true
    end
  end

  # Stub to be overridden for an object to launch prerequisites to needed attributes
  def request_dependencies
  end

  # Once the entities we depend on have settled, we take on their values
  def adopt_dependencies
    super if defined? super
  end

  # Take on an attribute from elsewhere, so long as it's open locally
  # (has never been set, or explicitly declared needed)
  def adopt_dependency attrib, dependent, dependent_attrib=attrib
    if attrib_open?(attrib) && dependent.attrib_ready?(dependent_attrib)
      accept_attribute attrib, dependent.send(dependent_attrib)
    end
  end

  # Register the attribute as closed, without setting it
  def attrib_done attrname
    return unless self.class.tracked_attributes.include?(attrname.to_sym)
    # No further work is needed on this attribute => clear 'needed' bit and set the 'ready' bit
    self.send :"#{attrname}_needed=", false
    self.send :"#{attrname}_ready=", true
  end

  # This is syntactic sugar to test whether an attribute MAY be set, either
  # 1) before it's been set, or the ready bit has been otherwise cleared; or
  # 2) it's been asked to refresh (needed bit is true, regardless whether it's ready or not)
  def attrib_open? attrib_sym
    !send(:"#{attrib_sym}_ready") || send(:"#{attrib_sym}_needed")
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

  # Which attributes are open?
  def open_attributes
    self.class.tracked_attributes.select { |attrname| attrib_open?(attrname) }
  end

  # Reduce the hash to values that are either open or untracked
  def assignable_values hsh
    hsh.slice(open_attributes).merge hsh.except(self.class.tracked_attributes)
  end

  # Report on the 'ready' bit for the named attribute
  def attrib_ready? attrib_sym
    send :"#{attrib_sym}_ready"
  end

  private

  # Convenience methods, for internal use only

  # Report on the 'needed' bit for the named attribute.
  # If no attribute specified, report whether ANY attribute is needed
  def attrib_needed? attrib_sym = nil
    attrib_sym.nil? ? needed_attributes.present? : send(:"#{attrib_sym}_needed")
  end

  # Set the 'ready' bit for the attribute and return the attribute_sym iff wasn't ready before
  def attrib_ready! attrib_sym, ready_now=true
    unless attrib_ready?(attrib_sym) == ready_now
      send :"#{attrib_sym}_ready=", ready_now
      attrib_sym
    end
  end

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

end

