module Querytags

  # Return the set of tags in the current query, as supplied by params[:querytags]
  # We also stash the last set of strings
  def querytags
    return @querytags if @querytags # Memoize
    newspecial = {}
    # Accumulate resulting tags here:
    @querytags = []
    if querytext = params[:querytags]
      oldspecial = session[:querytags] || {}
      querytext.split(",").each do |e|
        e.strip!
        if (e=~/^\d*$/) # numbers (sans quotes) represent existing tags that the user selected
          @querytags << Tag.find(e.to_i)
        elsif e=~/^-\d*$/ # negative numbers (sans quotes) represent special tags from before
          # Re-save this one
          tag = Tag.new(name: (newspecial[e] = oldspecial[e]))
          tag.id = e.to_i
          @querytags << tag
        else
          # This is a new special tag. Convert to an internal tag and add it to the cache
          name = e.gsub(/\'/, '').strip
          unless tag = Tag.strmatch(name, {matchall: true, uid: @userid}).first
            tag = Tag.new(name: name)
            unless oldspecial.find { |k, v| (newspecial[k] = v and tag.id = k.to_i) if v == name }
              tag.id = -1
              # Search for an unused id
              while (newspecial[tag.id.to_s] || oldspecial[tag.id.to_s]) do
                tag.id = tag.id - 1
              end
              newspecial[tag.id.to_s] = tag.name
            end
          end
          @querytags << tag
        end
      end
    end
    # Have to revise querytags to reflect special tags because otherwise, IDs will get
    # revised on the next read from DB
    if newspecial.count > 0
      session[:querytags] = newspecial
    else
      session.delete :querytags
    end
    @querytags
  end

end