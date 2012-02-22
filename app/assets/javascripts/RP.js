
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
