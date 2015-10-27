class String

  def extensions_to_classes
    this = nil
    self.split('.').collect { |substr|
      this = this ? "#{this}-#{substr}" : substr
    }.join ' '
  end
  
  def extensions_to_selector
    this = nil
    self.split('.').collect { |substr|
      this = this ? "#{this}-#{substr}" : substr
    }.join '.'
  end

  def to_boolean
    %w{ true TRUE t T 1 }.include? self
  end

  # Return nil if the string is empty. Also defined on NilClass, so empty strings and nil both return nil
  def if_present
    self unless self.empty?
  end
end