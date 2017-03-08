/**
 * Created by upstill on 3/9/17.
 */
/* Attend to input fields with placeholders in the absence of HTML5 */
/* Thanks to http://webdesignerwall.com/tutorials/cross-browser-html5-placeholder-text */
$(document).ready(function() {

    if (!Modernizr.placeholder || true) {

        $('[placeholder]:not(.token-input-field)').focus(function () {
            var input = $(this);
            if (input.val() == input.attr('placeholder')) {
                input.val('');
                input.removeClass('placeholder');
            }
        }).blur(function () {
            var input = $(this);
            if (input.val() == '' || input.val() == input.attr('placeholder')) {
                input.addClass('placeholder');
                input.val(input.attr('placeholder'));
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

