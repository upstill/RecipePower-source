replacements = []
replacements += item_replacements(@absorber.decorate, [:table, :card]) if @absorber
replacements += item_deleters(@to_delete, [:table, :card]) if @to_delete
{
    # done: true, # i.e., editing is finished, close the dialog, if any
    replacements: replacements
    # followup: pagelet_followup(@decorator)
}.merge(flash_notify).to_json
