/**
 * Created by upstill on 3/9/17.
 */
/* Attend to input fields with placeholders in the absence of HTML5 */
/* Thanks to http://webdesignerwall.com/tutorials/cross-browser-html5-placeholder-text */
$(document).ready(function() {

    if (!Modernizr.placeholder) {

        $('[placeholder]:not(.token-input-field)').focus(function () {
            // When focus moves to a placeholder field, remove the placeholder text.
            // If it's a password field, change the type back to 'password'
            var input = $(this);
            if (input.val() == input.attr('placeholder')) {
                input.val('');
                input.removeClass('placeholder');
                if (input.hasClass('password')) {
                    input.prop('type', 'password');
                }
            }
        }).blur(function () {
            var input = $(this);
            // When focus leaves a placeholder field, fill it with the placeholder text if empty.
            // If it's a password field, change the type to 'text' so the placeholder shows.
            if (input.val() == '' || input.val() == input.attr('placeholder')) {
                input.addClass('placeholder');
                input.val(input.attr('placeholder'));
                if (input.hasClass('password')) {
                    input.prop('type', 'text');
                }
            }
        }).blur();
        $('[placeholder]:not(.token-input-field)').parents('form').submit(function () {
            $(this).find('[placeholder]').each(function () {
                var input = $(this);
                if (input.val() == input.attr('placeholder')) {
                    input.val('');
                }
            })
        });

    }
    ;
})

