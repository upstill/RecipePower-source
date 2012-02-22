// GUARANTEED NECESSARY
// Callback to respond to value changes on form elements,
//  triggering immediate response
function queryChange() {
    // queryformHit(this.form);
    queryformHit($("form")[0]);
}

// Callback to respond to select on list owner,
//  triggering immediate response
function queryownerChange() {
    queryheaderHit(this.form);
    queryformHit(this.form);
}

function queryListmodeChange() {
    var form = $("form")[0];
    var formstr = $(form).serialize();
    // Add the popup to the rcpquery params in the form
    var div = $('select#rcpquery_listmode_str')[0];
    var divstr = $(div).serialize();
    var datastr = "element=tabnum&" + formstr + "&" + divstr;
    //...and proceed with the form hit as usual
    var resp =
    jQuery.ajax({
        type: "POST",
        url: form.action,
        data: datastr,
        // Submit the data from the form
        dataType: "html",
        success: queryresultsUpdate
    }
    );
}

// Handle a hit on one of the query fields by POSTing the whole form, then
// (via callback) updating the results list
function queryformHit(form) {
    var resp =
    jQuery.ajax({
        type: "POST",
        url: form.action,
        data: "element=tabnum&" + $(form).serialize(),
        // Submit the data from the form
        dataType: "html",
        success: queryresultsUpdate
    }
    );
}

