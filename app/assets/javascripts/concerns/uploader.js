$(function () {
});

function resettle(uploadElmt) {
    var form = $($(uploadElmt).parents('form:first'));
    var submitButton = form.find('input[type="submit"]');
    uploadElmt.value = "";
    submitButton.prop('disabled', false);
    $('div.progress').hide();
}

function abort_upload(uploadElmt, msg) {
    var params = $(uploadElmt).data('directUpload');
    var inputSelector = "input#" + params.input_id;
    var imageSelector = "img#" + params.img_id;

    msg = msg || "Upload failed!"
    // Copy the original input value back to the image from its associated input element
    var url = $(inputSelector).attr("value")
    if (!url || url === "") {
        url = "/assets/NoPictureOnFile.png";
    }
    $(imageSelector).attr("src", url);
    RP.notifications.post(msg, "alert");
    $('div.bootstrap-filestyle input.form-control').css({"background-color": "#b94a48", "color": "white"})

    resettle(uploadElmt);
}

function finalize_upload(uploadElmt, url) {
    var params = $(uploadElmt).data('directUpload');
    var inputSelector = "input#" + params.input_id;
    var imageSelector = "img#" + params.img_id;

    $(inputSelector).attr("value", url);
    $(imageSelector).attr("src", url);
    RP.notifications.post("Picture is uploaded and ready to go", "popup");
    $('div.bootstrap-filestyle input.form-control').css({"background-color": "#006600", "color": "white"})

    resettle(uploadElmt);
}

function uploader_init(elem) {
    var upload_params = $(elem).data('directUpload');
    $(elem).filestyle({buttonText: "Upload picture", iconName: "glyphicon-picture", buttonBefore: 'true'});
    if (upload_params) {
        var formData = upload_params.form_data;
        var url = upload_params.url;
        var url_host = upload_params.url_host;
        var fileInput = $(elem);
        var form = $(fileInput.parents('form:first'));
        var submitButton = form.find('input[type="submit"]');
        var progressBar = $("<div class='bar'></div>");
        var barContainer = $("<div class='progress'></div>").append(progressBar);
        var resizeImage = !(/Android(?!.*Chrome)|Opera/
            .test(window.navigator && navigator.userAgent));
        fileInput.after(barContainer);
        fileInput.fileupload({
            fileInput: fileInput,
            url: url,
            type: 'POST',
            disableImageResize: !resizeImage,
            imageMaxWidth: 200,
            autoUpload: false, // true,
            formData: formData,
            paramName: 'file', // S3 does not like nested name fields i.e. name="user[avatar_url]"
            dataType: 'XML',  // S3 returns XML if success_action_status is set to 201
            replaceFileInput: false,
            progressall: function (e, data) {
                var progress = parseInt(data.loaded / data.total * 100, 10);
                progressBar.css('width', progress + '%')
            },
            start: function (e) {
                submitButton.prop('disabled', true);
                $('div.progress').show();
                progressBar.
                    css('background', 'green').
                    css('display', 'block').
                    css('width', '0%').
                    text("Loading...");
            },
            done: function (e, data) {
                progressBar.text("Uploading done");
                // extract key and generate URL from response
                var key = $(data.jqXHR.responseXML).find("Key").text();
                // Make the key safe for subsequent use as a URL by escaping funky filename characters
                var path = key.split('/');
                path.push(encodeURIComponent(path.pop()));
                var url = '//' + url_host + '/' + path.join('/');
                finalize_upload(elem, "http:" + url);
                // create hidden field
                // var input = $("<input />", {type: 'hidden', name: fileInput.attr('name'), value: url})
                // form.append(input);
                // $('img#image_id')[0].src = "http:"+url
            },
            fail: function (e, data) {
                abort_upload(elem);
                console.debug( upload_params );
                progressBar.
                    css("background", "red").
                    text("Failed");
            }
        });
        $('div.progress').hide();
    }
    return upload_params;
}

function uploader_unpack() {
    $('input:file.directUpload').each(function (i, elem) {
        var params = uploader_init(elem);
        $(elem).change(function () {
            var input = this;
            if (input.files && input.files[0]) {
                var reader = new FileReader();
                var image = $("img#" + params.img_id)[0];
                reader.onload = function (e) {
                    image.onerror = function () {
                        // Abort! Copy the input value back to the image
                        var x = 2;
                        if (!$('div.bootbox-alert')[0]) {
                            abort_upload(elem, "That file isn't a picture!");
                        }
                    }
                    var passOn = function () {
                        // Successful image load => go ahead and upload it
                        $(image).off("load", passOn);
                        if (input.files.length > 0) {
                            $(input).fileupload('add', {
                                autoUpload: true,
                                disableImageResize: false,
                                imageMaxWidth: 200,
                                files: input.files
                            });
                        }
                    };
                    $(image).on("load", passOn);
                    $(image).attr('src', e.target.result);
                }
                var alt = $(input).val()
                reader.readAsDataURL(input.files[0]);
            }
        });
    });
}
