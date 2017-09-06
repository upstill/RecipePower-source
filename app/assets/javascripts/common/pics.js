RP = RP || {};

function doFitImage(evt) {
    fitImage(evt.target)
}

function layoutMasonryOnLoad(event) {
    $(event.target).closest('div.js-masonry').masonry('layout');
}

function onImageErrorEvent(event) {
    var image = event.currentTarget;
    return onImageError(image);
}

function onImageError(image) {
    if (!$(image).hasClass('empty')) { // Failure on original load
        if (image.alt && (image.alt.match(/\.(jpg|tif|tiff|gif|png)$/) != null)) {
            image.src = image.alt;
            image.alt = ""
        } else {
            image.src = $(image).data("bogusurlfallback") || "";
        }
        if( $(image).attr('src').length == 0) {
            $(image).addClass('bogus').addClass('empty');
            $(image).trigger('image:empty')
        }
    }
    return true;
}

function get_image(imageSel) {
    return $(imageSel).attr('src');
}

// Set the source for the preview image, only loading the URL into the form field when the image is successfully loaded
// NB: an empty image url is valid, and substituted in the image (but not in the form) with a fallback url
function set_image_safely(imageElmt, url, formsel, callback) {
    $(formsel).attr('value', url || "");
    if (url.length < 1) {  // Substitute empty url with placeholder for display purposes only
        url = $(imageElmt).data('emptyurlfallback') || ""
    }
    if (url.length < 1) {  // If the url is STILL empty, render the image invisible
        $(imageElmt).addClass('empty')
    } else {
        $(imageElmt).removeClass('empty')
    }
    $(imageElmt).removeClass('bogus'); // Pending load attempt
    var oldsrc = $(imageElmt).attr('src');
    // Apply the display url to the preview, and save the form selector and actual URL pending successful load
    $(imageElmt).removeClass("loaded").attr("src", url).data("formsel", formsel);
    imgLoad = imagesLoaded(imageElmt);
    imgLoad.on('progress', function (instance, image) {
        var img = image.img;
        var fallback;
        if (image.isLoaded) {
            $(img).addClass("loaded");
        } else {
            $(img).addClass("bogus").removeClass("loaded");
            if(!(callback && callback(img, oldsrc))) {
                img.src = $(img).data("bogusurlfallback") || "";
            }
        }
        $(image.img).trigger('ready')
    });
//	}
    return false;
}

// Copy an input URL to both the preview image and the (hidden) form field
function previewImg(inputsel, imagesel, formsel) {
    // Copy the url from the input field to the form field
    var url = $(inputsel).attr("value");

    // If not specified by the selector, the preview image is a sibling of the input element
    // var imageElmt = $(imagesel)[0] || $('img', inputElmt.parentElement)[0];
    // For display purposes we use a no-picture picture
    set_image_safely(imagesel, url, formsel);
    return false;
}

// onload handler to validate image (since we can't use imagesLoaded for hardwired URLs)
RP.validate_img = function (event) {
    var img = event.target;
    if (!img.complete) { // Loaded but not complete => error
        if(!$(img).hasClass("bogus")) {   // Replace url with invalid-image url if this is the first try
            $(img).addClass("bogus").addClass('empty');
            img.src = $(img).data('bogusurlfallback') || "";
        }
    }
};

