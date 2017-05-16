replacements = []
replacements += item_replacements(@absorber.decorate, [:table, :card]) if @absorber
if @to_delete
  replacements += item_deleters(@to_delete, [:table, :card])
elsif @changed
  replacements += item_replacements(@changed.decorate, [:table, :card])
end
{
    # done: true, # i.e., editing is finished, close the dialog, if any
    replacements: replacements
    # followup: pagelet_followup(@decorator)
}.merge(flash_notify).to_json
