# Generic JSON response for updating a @decorator and replacing it wherever it might go
{
    done: true, # i.e., editing is finished, close the dialog
}.merge(flash_notify).to_json
