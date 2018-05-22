class Array
  # Return nil if the string is empty. Also defined on NilClass, so empty strings and nil both return nil
  def if_present default=nil
    self.empty? ? default : self
  end

end