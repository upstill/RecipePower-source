# Tracking of attributes.                                                                                   flags
# Each tracked attribute has 2 boolean fields embedded in the :attr_tracking attribute:
# <attr>_needed indicates an unfulfilled need for the value
# <attr>_ready indicates that the value has been accepted
include FlagShihTzu  # https://github.com/pboling/flag_shih_tzu
module Trackable
  extend ActiveSupport::Concern

  included do
    # Launch for getting attributes IF they have been declared as needed before saving,
    # e.g., by an after_initialize callback
    after_save do |entity|
      # Any attributes that remain unsatisfied will trigger a search for more
      bkg_launch true if !bad? && performance_required
      # (re)Launch dj as necessary to gather attributes from MercuryResult and Gleaning
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
              puts "#{self.class} writing #{printable} to #{attrname}"
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
            puts "#{self.class} reading #{attrname}"
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

  # Handle tracking-related calls. The form is 'attrname_verb', where
  # * attrname is the name of an attribute, possibly but not necessarily tracked
  # * verb indicates what to do with the attribute, i.e.
  #   -- 'accept' means to assign the attribute, clear the associated 'needed' bit and set the 'ready' bit
  #   -- 'if_ready' is for reporting a value. If the corresponding 'ready' bit is true, invoke the passed block with the attribute value
  def method_missing namesym, *args
    if match = namesym.to_s.match(/(.*)_(accept|if_ready|open\?|ready\?|needed!)$/)
      attrname, verb = match[1..2]
      case verb
      when 'needed!'
        attrib_needed! attrname, args.last != false
      when 'ready?'
        attrib_ready? attrname
      when 'open?' # The attribute may be changed if not previously set (ready), OR if explicitly needed
        !attrib_ready?(attrname) || attrib_needed?(attrname)
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
  # In the absence of specified attribs, defaults to ALL tracked attributes (excepting those specified by :except).
  # The syntax is a (possibly empty) list of attributes to refresh, possibly followed by a hash of flags:
  # :except provides a list of attributes NOT to refresh
  # :immediate if true, forces the attribute(s) to update synchronously before returning
  # :restart forces any dependencies to ALSO be regenerated
  def refresh_attributes attribs=nil, except: [], immediate: false, restart: true
    # No attribs => update all tracked attributes
    attribs ||= self.class.tracked_attributes if except.present?
    attribs -= except.map &:to_sym
    return if attribs.blank? # Return if there are no attributes to be refreshed
    attribs &= attribs.map(&:to_sym)
    # Invalidate all given attributes and mark them as needed
    attribs_ready! attribs, false
    attribs_needed! attribs
    # Now launch the generation process, either synchronously or asynchronously
    if immediate
      ensure_attributes attribs, overwrite: true, restart: restart
    else
      request_attributes attribs, overwrite: true, restart: restart
    end
  end

  # Ensure that the given attributes have been acquired if at all possible.
  # Calling ensure_attributes with no arguments means that all needed attributes should be acquired.
  # This may entail forcing the object's delayed job to completion BEFORE RETURNING
  # NB: needed attributes other than those specified may be acquired as a side effect
  def ensure_attributes minimal_attributes=needed_attributes, overwrite: false, restart: false
    request_attributes minimal_attributes, overwrite: overwrite, restart: restart
    # Try to acquire attributes from their dependencies, forcing them to completion
    adopt_dependencies synchronous: true
    # If any attributes are still needed after completing dependencies, drive our background job to completion
    bkg_land! true if (minimal_attributes & needed_attributes).present?
  end

  # A Trackable winds up its (successful) work by taking any attributes from its dependencies
  def success job=nil
    adopt_dependencies
    # Now, throw an error if any needed attributes remain unfulfilled
    needed_attributes.each { |attrib| errors.add attrib, 'couldn\'t be extracted' }
    super if defined?(super)
  end

  # Notify the object of a need for certain derived values. They may be derived immediately or in background.
  # A minimal set of attributes may be required at the current time, which may be a subset of all needed attributes
  def request_attributes minimal_set=nil, overwrite: false, restart: false
    # Set the :needed flag for those in the list that aren't already needed or ready.
    # ATTRIBUTES THAT ARE READY ARE NOT DECLARED NEEDED--UNLESS THE OVERWRITE FLAG IS ON
    minimal_set = minimal_set ? attribs_needed!(minimal_set, overwrite: overwrite) : needed_attributes
    if persisted?
      if performance_required minimal_set, overwrite: overwrite, restart: restart # Remove 'bad' status which would prevent launching
        self.status = 'virgin'
        save if changed?
        return true
      end
    elsif performance_required(minimal_set, overwrite: overwrite, restart: restart) && (restart || !bad?) # Launch all objects that we depend on, IFF we haven't failed prior
      puts "Requesting attributes #{minimal_set} of #{self} ##{id}"
      bkg_launch true
      return true
    end
    return false
  end

  # Stub to be overridden that an object uses to:
  # 1) hold until prequisites are fulfilled by others
  # 2) send heavy computing into background.
  # In either case, return true to launch for background processing
  # NB: this is an object's chance to extract values without awaiting others, if possible
  # return: a flag to launch for dependent data
  def performance_required which_attribs=needed_attributes, overwrite: false, restart: false
    restart || (needed_attributes & (overwrite ? (which_attribs - ready_attributes) : which_attribs)).present?
  end

  # Once the entities we depend on have settled, we take on their values
  def adopt_dependencies synchronous: false
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
  # 0) because it's not tracked
  # 1) before it's been set, or the ready bit has been otherwise cleared; or
  # 2) it's been asked to refresh (needed bit is true, regardless whether it's ready or not)
  def attrib_open? attrib_sym
    !self.class.tracked_attributes.include?(attrib_sym) || !send(:"#{attrib_sym}_ready") || send(:"#{attrib_sym}_needed")
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

  # Set the 'needed' bit for the attribute and return the attribute_sym iff wasn't needed before
  def attrib_needed! attrib_sym, needed_now=true
    unless attrib_needed?(attrib_sym) == needed_now
      send :"#{attrib_sym}_needed=", needed_now
      attrib_sym
    end
  end

  # Set the 'ready' bit for the attribute and return the attribute_sym iff wasn't ready before
  def attrib_ready! attrib_sym, ready_now=true
    unless attrib_ready?(attrib_sym) == ready_now
      send :"#{attrib_sym}_ready=", ready_now
      attrib_sym
    end
  end

  # Declare the need for a set of attributes
  # overwrite: flag indicating whether a ready attribute should be declared needed anyway
  # return: the set of attributes that are actually needed FROM THE GIVEN SET
  # That is, attributes that are ALREADY needed will only be returned if requested here
  def attribs_needed! attrib_syms, overwrite:false
    (overwrite ? (attrib_syms - ready_attributes) : attrib_syms).each { |attrib_sym| attrib_needed! attrib_sym }
  end

  def attribs_ready! attrib_syms, ready_now=true
    attrib_syms.each { |attrib_sym| attrib_ready! attrib_sym, ready_now }
  end

end

