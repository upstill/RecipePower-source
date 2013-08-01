
function checkForLoading(selector) {
	$(selector).one('load', function() {
	  fitImage(this);
	}).each(function() {
	  if(this.complete && !$(this).hasClass("loaded")) $(this).load();
	});
	
}
// Onload function for images, to fit themselves (found by id) into the enclosing container.
function fitImageOnLoad(selector) {
//	$(".stuffypic").one('load', () ->
//		fitImage this
//	).each () ->
//		if this.complete 
//			$(this).load();
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
		  $(img).css("padding-top", (frameHeight-newHeight)/2);
		  // $(img).css("left", 0);
		} else {
		  var newWidth = frameHeight*imgAR;
		  $(img).css("width", newWidth);
		  $(img).css("height", frameHeight);
		  // $(img).css("top", 0);
		  $(img).css("padding-left", (frameWidth-newWidth)/2);
		}
	}
  $(img).addClass("loaded")
	RP.collection.justify()
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
