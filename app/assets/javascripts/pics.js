
// Onload function for images, to fit themselves (found by id) into the enclosing container.
function fitImageOnLoad(selector) {
    $(selector).each(function() {
        fitImage(this);
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
	img.style.position = "relative";
    $(img).css("visibility", "visible");
    $(img).show();
    return true;
}
