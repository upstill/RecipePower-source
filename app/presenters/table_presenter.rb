class TablePresenter

  def initialize stats_hash, field_labels = {}
    @field_labels = field_labels
    @data = stats_hash
    @sortfield = field_labels.first[0]
  end

  # Return a list of the fields (in the original order) by name and symbol
  def fields
    @field_labels.collect { |k, v| { sym: k, name: v } }
  end

  def sort_field
    { sym: @sortfield, name: @field_labels[@sortfield] }
  end

  def rows
    @data
  end

  # To change this template use File | Settings | File Templates.
  def sort sortfield = :id, descending = false
    @sortfield = sortfield.to_sym
    reverse = descending ? -1 : 1
    @data = @data.compact.sort { |us1, us2|
      if us1[@sortfield] && us2[@sortfield]
        us1[@sortfield] <=> us2[@sortfield]
      elsif us1[@sortfield]
        1
      elsif us2[@sortfield]
        -1
      else
        0
      end * reverse
    }
  end

end