
// Called to replace the form's image with the given URL
function replaceImg(data) {
	debugger;
	if(data.url && data.url[0])
    pickImg('input#recipe_picurl', 'img.fitPic', data.url[0]);
    // pickImg('input.icon_picker', 'div.preview img', data.url[0]);
}

function PicPicker(ttl) {
	// Bring up a dialog showing the picture-picking fields of the page
	$("div.iconpicker").dialog({ // nee: iconpicker
		modal: true,
		width: 700,
		zIndex: 1200,
		title: (ttl || "Pick a Picture"),
		buttons: { Okay: function (event) {
			// Transfer the logo URL from the dialog's text input to the page text input
			// THE PICPICKER MUST BE ARMED WITH NAMES IN ITS DATA
			var datavals = $("#PicPicker").attr("data").split(';');
			previewImg("input.icon_picker", datavals[1], "input#"+datavals[0]);
			$(this).dialog('close');
			// Copy the image to the window's thumbnail
		}}
	});
}

// Handle a click on a thumbnail image by passing the URL on to the 
// associated input field
function pickImg(inputsel, imagesel, url) {
	$(inputsel).attr("value", url );
	previewImg(inputsel, imagesel, "");
}

// Copy an input URL to both the preview image and the (hidden) form field
function previewImg(inputsel, imagesel, formsel) {
	// Copy the url from the input field to the form field
  var url = $(inputsel).attr("value");
	$(formsel).attr("value", url )
	
	// Set the image(s) to the URL and fit them in their frames
	var imageset = $(imagesel)
    imageset.hide();
	imageset.attr("src", url )
	fitImage(imageset[0])
}

// When a new URL is typed, set the (hidden) field box
function newImageURL(inputsel, formsel, picid) {
	var url = $(inputsel).attr("value")
	var thePic = $("#"+picid)
	var formField = $(formsel)
	formField.attr("value", url);
	thePic.attr("src", url)
	return false;
}
