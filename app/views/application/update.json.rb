# Generic JSON response for updating a @decorator and replacing it wherever it might go
{
    done: true, # i.e., editing is finished, close the dialog
    replacements: (@decorator.destroyed? ? item_deleters(@decorator) : item_replacements(@decorator)),
    followup: pagelet_followup(@decorator, @decorator.destroyed?) # follow up by replacing the page, if it's the page for the entity
}.merge(flash_notify).to_json
