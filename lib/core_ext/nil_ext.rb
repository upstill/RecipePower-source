class NilClass
  # if_present is defined for the benefit of String class
  def if_present default=nil
    default
  end
end