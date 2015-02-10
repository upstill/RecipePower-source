class Hash

  # Move a (set of) key/value pair(s) from another hash if there
  def take key_or_keys, h
    (key_or_keys.is_a?(Array) ? key_or_keys : [key_or_keys]).each { |k|
      self[k] = h[k] if h.has_key?(k)
    }
  end

end