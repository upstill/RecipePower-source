RP = RP || {}

function doFitImage(evt) {
    fitImage(evt.target)
}

function fitImage(img) {

    if (!img) return false;

    var parent = img.parentElement, frameWidth, frameHeight, picWidth, picHeight;

    if (!(img.complete &&
        (img.width > 5) &&
        (img.height > 5) &&
        ((picWidth = img.naturalWidth) > 5) &&
        ((picHeight = img.naturalHeight) > 5) &&
        ((frameWidth = $(parent).width()) > 5) &&
        ((frameHeight = $(parent).height()) > 5)
        )) return false;

    var frameAR = frameWidth / frameHeight;
    var imgAR = picWidth / picHeight;
    var fillmode;
    if (fillmode = $(img).data("fillmode")) {
        if (fillmode == "width") {
            // Size image to fit parent's width
            $(img).css("width", frameWidth);
            $(img).css("height", frameWidth / imgAR);
        }
    } else {
        if (imgAR > frameAR) {
            var newHeight = frameWidth / imgAR;
            $(img).css("width", frameWidth);
            $(img).css("height", newHeight);
            // $(img).css("padding-left", 0);
            // $(img).css("padding-top", (frameHeight-newHeight)/2);
            // $(img).css("left", 0);
        } else {
            var newWidth = frameHeight * imgAR;
            $(img).css("width", newWidth);
            $(img).css("height", frameHeight);
            // $(img).css("top", 0);
            // $(img).css("padding-top", 0);
            // $(img).css("padding-left", (frameWidth-newWidth)/2);
        }
    }
    $(img).addClass("loaded")
    var fcn = RP.named_function("RP.collection.rejustify")
    if (fcn) fcn();
    return true;
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

function set_image_safely(imageElmt, url, formsel) {
    if (url.length < 1) {
        url = $(imageElmt).data('fallbackurl') || "/assets/NoPictureOnFile.png"
        $(imageElmt).addClass('bogus')
    } else {
        $(imageElmt).removeClass('bogus')
    }
//	if($(imageElmt).attr("src") != url) {
    $(imageElmt).removeClass("loaded").attr("src", url).data("formsel", formsel)
    imgLoad = imagesLoaded(imageElmt);
    imgLoad.on('progress', function (instance, image) {
        var img = image.img
        if (image.isLoaded) {
            var formsel = $(img).data("formsel")
            $(img).addClass("loaded")
            $(formsel).attr("value", img.src)
        } else {
            $(img).addClass("bogus").removeClass("loaded")
            img.src = "/assets/BadPicURL.png"
        }
        $(image.img).trigger('ready')
    })
//	}
    return false;
}

// Place an image URL into both a preview image  and an accompanying input field, if any
// The img element is the first sibling of the input by default,
// but may be identified with an id stored in the 'imageid' data field of the input element
function imagePreviewWidgetSet(imgID, inputID, url) {
    set_image_safely("img#" + imgID, url, "input#" + inputID)
    return false;
}

// onload handler to validate image
RP.validate_img = function (event) {
    var img = event.target;
    if (!img.complete) {
        if !$(img).hasClass("bogus"))) {   // Replace url with invalid-image url
            $(img).addClass("bogus")
            if(img.src.length < 1) {
                # Empty URL: not a bad URL but still needs standin
                img.src = $(imageElmt).data('fallbackurl') || "/assets/NoPictureOnFile.png"
            } else
                img.src = "/assets/BadPicURL.png";
        }
    }
}
