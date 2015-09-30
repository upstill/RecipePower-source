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
end