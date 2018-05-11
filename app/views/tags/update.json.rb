@touched ||= [@tag]
replacements =
@touched.inject([]) { |memo, tag|
  memo +
      (tag.destroyed? ? item_deleters(tag, [:table, :card]) : item_replacements(tag.decorate, [:table, :card]))
}
{
    done: true, # i.e., editing is finished, close the dialog, if any
    replacements: replacements,
    followup: pagelet_followup(@decorator, @decorator.destroyed?)
}.merge(flash_notify).to_json
