/* This file is loaded by the RecipePower bookmarklet. */

if (!($ = window.jQuery)) { // typeof jQuery=='undefined' works too  
    script = document.createElement( 'script' );  
    script.src = 'http://ajax.googleapis.com/ajax/libs/jquery/1.7.1/jquery.min.js';  
    script.onload=recipePowerCapture;  
    document.body.appendChild(script);  
}  
else {  
    recipePowerCapture();  
}  

function recipePowerCapture() {
    var resource = "http://localhost:5000/recipes/capture";
    alert( "Got recipePowerCapture!");
    var obj = 
	  { url: window.location.href,
	 	title: document.title,
		area: "at_top",
		how: "modeless" }
		
	recipePowerGetAndRunHTML(resource, obj)
}
