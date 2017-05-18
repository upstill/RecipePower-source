if flash.empty?
  replacements = []
  @touched.each { |tag|
    replacements += tag.destroyed? ?
        item_deleters(tag, [:table, :card]) :
        item_replacements(tag.decorate, [:table, :card])
  }
  {
      # done: true, # i.e., editing is finished, close the dialog, if any
      replacements: replacements
      # followup: pagelet_followup(@decorator)
  }.to_json
else
  flash_notify.to_json
end
