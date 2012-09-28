/* Bookmarklet for loading a dialog from RecipePower, injecting it into a foreign page,
  and running the dialog from it. This involves 
	1) ensuring that jQuery is available by loading it from the jQuery site;
	2) hitting RecipePower for app-specific HTML, including javascript for running the dialog;
	3) injecting the dialog into the page;
	4) handling cancel and save events in the appropriate way.
  When the user Saves the dialog, we also need to hit RecipePower to get the result of the 
    interaction. If it was successful, we need to optionally move on to the next step (for 
    example, if the user needs to log in before saving a cookmark) or reverse the injection.
    If it was unsuccessful, we need to reload the dialog, perhaps with some error message.
*/
/* Old bookmarklet code:
{<a class="bookmarklet" 
    title="Cookmark" 
    href="javascript:void(
		window.open('http://www.recipepower.com/recipes/new?
		     url='+encodeURIComponent(window.location.href)+
		    '&title='+encodeURIComponent(document.title)+
		    '&notes='+encodeURIComponent(''+(window.getSelection?window.getSelection():document.getSelection?document.getSelection():document.selection.createRange().text))+
		    '&v=6
			 &jump=yes',
		  %20'popup',
		  %20'width=600,
		  %20height=300,
		  %20scrollbars,
		  %20resizable'))">
*/
(function() {
	/* This is the naked bookmarklet code. We need to acquire not only the HTML for the dialog
	 but the code to run it, possibly including jQuery itself, so we have a bootstrapping problem. */
	// Send request for contents of our div dialog.
	// Load the HTML into the div.
	// Execute the javascript booter.
	// Run the dialog.
})();

(function() {
  var el=document.createElement('div'),
   b=document.getElementsByTagName('body')[0];
   otherlib=false,
   msg='';
  el.style.position='fixed';
  el.style.height='32px';
  el.style.width='220px';
  el.style.marginLeft='-110px';
  el.style.top='0';
  el.style.left='50%';
  el.style.padding='5px 10px';
  el.style.zIndex = 1001;
  el.style.fontSize='12px';
  el.style.color='#222';
  el.style.backgroundColor='#f99';
  if(typeof jQuery!='undefined') {
 msg='This page already using jQuery v'+jQuery.fn.jquery;
 return showMsg();
  } else if (typeof $=='function') {
 otherlib=true;
  }
  // more or less stolen form jquery core and adapted by paul irish
  function getScript(url,success){
 var script=document.createElement('script');
 script.src=url;
 var head=document.getElementsByTagName('head')[0],
  done=false;
 // Attach handlers for all browsers
 script.onload=script.onreadystatechange = function(){
   if ( !done && (!this.readyState
     || this.readyState == 'loaded'
     || this.readyState == 'complete') ) {
  done=true;
  success();
  script.onload = script.onreadystatechange = null;
  head.removeChild(script);
   }
 };
 head.appendChild(script);
  }
  getScript('http://code.jquery.com/jquery-latest.min.js',function() {
 if (typeof jQuery=='undefined') {
   msg='Sorry, but jQuery wasn\'t able to load';
 } else {
   msg='This page is now jQuerified with v' + jQuery.fn.jquery;
   if (otherlib) {msg+=' and noConflict(). Use $jq(), not $().';}
 }
 return showMsg();
  });
  function showMsg() {
 el.innerHTML=msg;
 b.appendChild(el);
 window.setTimeout(function() {
   if (typeof jQuery=='undefined') {
  b.removeChild(el);
   } else {
  jQuery(el).fadeOut('slow',function() {
    jQuery(this).remove();
  });
  if (otherlib) {
    $jq=jQuery.noConflict();
  }
   }
 } ,2500);
  }
})();