
function doFitImage(evt) {
    fitImage(evt.target)
}

function fitImage(img) {

	if(!img) return false;

	var parent = img.parentElement, frameWidth, frameHeight, picWidth, picHeight;
	
	if (!(img.complete && 
			(img.width > 5) && 
			(img.height > 5) &&
			((picWidth = img.naturalWidth) > 5) && 
			((picHeight = img.naturalHeight) > 5) &&
			((frameWidth = $(parent).width()) > 5) &&
			((frameHeight = $(parent).height()) > 5)
	)) return false;

	var frameAR = frameWidth/frameHeight;
	var imgAR = picWidth/picHeight;
	var fillmode;
	if (fillmode = $(img).data("fillmode")) {
		if(fillmode == "width") {
			// Size image to fit parent's width
			$(img).css("width", frameWidth);
			$(img).css("height", frameWidth/imgAR );
		}
	} else {
		if(imgAR > frameAR) { 
		  var newHeight = frameWidth/imgAR;
		  $(img).css("width", frameWidth);
		  $(img).css("height", newHeight);
		  // $(img).css("padding-left", 0);
		  // $(img).css("padding-top", (frameHeight-newHeight)/2);
		  // $(img).css("left", 0);
		} else {
		  var newWidth = frameHeight*imgAR;
		  $(img).css("width", newWidth);
		  $(img).css("height", frameHeight);
		  // $(img).css("top", 0);
		  // $(img).css("padding-top", 0);
		  // $(img).css("padding-left", (frameWidth-newWidth)/2);
		}
	}
  $(img).addClass("loaded")
	var fcn = RP.named_function("RP.collection.rejustify")
	if(fcn) fcn();
  return true;
}

// Copy an input URL to both the preview image and the (hidden) form field
function previewImg(inputsel, imagesel, formsel) {
	// Copy the url from the input field to the form field
  var inputElmt = $(inputsel)[0];
  var url = $(inputElmt).attr("value");
  if (url != $(formsel).attr("value"))
		$(formsel).attr("value", url )

    // If not specified by the selector, the preview image is a sibling of the input element
	var imageElmt = $(imagesel)[0] || $('img', inputElmt.parentElement)[0];
	// For display purposes we use a no-picture picture
	if (url.length < 1) url = "/assets/NoPictureOnFile.png"
	if($(imageElmt).attr("src") != url) {
        $(imageElmt).removeClass("loaded");
        $(imageElmt).attr("src", url )
		// fitImage(imageset[0])
	}
  return false;
}
