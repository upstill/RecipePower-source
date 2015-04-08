{
    replacements: [
        [ 'form.user_about', with_format("html") { render "form_about", user: @user } ]
    ]
}.merge(flash_notify).to_json