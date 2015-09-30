class String
  def uncapitalize
    self[0, 1].downcase + self[1..-1]
  end

  # Ensure that the space-separated string of words includes those listed in new
  def assert_words new
    wordlist = split + (new.is_a?(String) ? new.split : new.map(&:to_s))
    wordlist.compact.uniq*' '
  end

  # If a string has content, provide it, otherwise execute an attached block
  def or_fallback
    present? ? self : yield
  end
end

class NilClass
  def or_fallback
    yield
  end
end
