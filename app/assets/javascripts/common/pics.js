
// Onload function for images, to fit themselves (found by id) into the enclosing container.
function fitImageOnLoad(selector) {
    $(selector).each(function() {
        fitImage(this);
    });
}

function ensureOnload(selector, context) {
		$(selector, context).load( function(evt) {
			fitImage(evt.currentTarget);
			x=2;
		});
}

function fitImage(img) {

    if (!(img && img.complete)) {
        return false;
    }

    if(!(img.width > 5 && img.height > 5)) {
		return false;
	}
	
	var picWidth = img.naturalWidth; // width();
	var picHeight = img.naturalHeight; // height();

    // In case the image hasn't loaded yet
	if(!(picWidth > 5 && picHeight > 5)) {
		return false;
	}
	
	var parent = img.parentElement;
	var frameWidth = $(parent).width(); // img.parentElement.clientWidth;
	var frameHeight = $(parent).height(); // img.parentElement.clientHeight;

	if(!(frameWidth > 5 && frameHeight > 5)) {
		return false;
	}

	var frameAR = frameWidth/frameHeight;
	var imgAR = picWidth/picHeight;
	if(imgAR > frameAR) { 
	  var newHeight = frameWidth/imgAR;
	  $(img).css("width", frameWidth);
	  $(img).css("height", newHeight);
	  $(img).css("top", (frameHeight-newHeight)/2);
	  $(img).css("left", 0);
	} else {
	  var newWidth = frameHeight*imgAR;
	  $(img).css("width", newWidth);
	  $(img).css("height", frameHeight);
	  $(img).css("top", 0);
	  $(img).css("left", (frameWidth-newWidth)/2);
	}
  // $(parent).css("display", "block");
  $(img).addClass("loaded")
  return true;
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
  if (url != $(formsel).attr("value"))
		$(formsel).attr("value", url )
	
	// Set the image(s) to the URL and fit them in their frames
	var imageset = $(imagesel)
	if(imageset.attr("src") != url) {
		imageset.removeClass("loaded");
		imageset.attr("src", url )
		fitImage(imageset[0])
	}
}
