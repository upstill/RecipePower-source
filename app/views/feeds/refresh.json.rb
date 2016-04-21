# Define response structure after editing a collectible
# Generic JSON response for updating an @decorator and replacing it wherever it might go
{
    followup: (pagelet_followup(@feed) if followup),
    replacements: item_replacements(@decorator)
}.merge(flash_notify).to_json
