
# Look up a constant for a particular kind of, e.g., Presenter, related to a class or its ancestors
def const_for object, qualifier=nil
  # First try investigating defined constants directly
  object.class.ancestors.detect { |anc|
    next if anc.to_s.match /^#</
    return nil if anc == ApplicationRecord # Stop checking at ApplicationRecord base class
    next if anc.to_s.match /::/
    classname = "#{anc}#{qualifier}"
    if Object.const_defined? classname
      return classname.constantize
    end
  }
end

