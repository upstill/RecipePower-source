{
    replacements: [
        [ 'form.user_image', with_format("html") { render "form_image", user: @user } ]
    ]
}.merge(flash_notify).to_json