  # Take a CSS dimension value and scale it by the given numerical factor
  def dim_scale given, sf
    numstr, unit = given.match(/([^a-zA-Z%]*)([a-zA-Z%]*$)/)[1,2]
    if unit != "%"
      i, f = numstr.to_i, numstr.to_f
      num = (i.to_f == f) ? i : f  # Keep it as an integer if possible
      (num * sf).to_s.sub(/\.0*$/,'')+unit  # Eliminate trailing 0's
    end
  end
