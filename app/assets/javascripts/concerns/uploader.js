$(function () {
    uploader_unpack();
});

function uploader_init(elem) {
    var data = $(elem).data('directUpload');
    if (data) {
        var formData = data.form_data;
        var url = data.url;
        var url_host = data.url_host;
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
            autoUpload: true,
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

                progressBar.
                    css('background', 'green').
                    css('display', 'block').
                    css('width', '0%').
                    text("Loading...");
            },
            done: function (e, data) {
                submitButton.prop('disabled', false);
                progressBar.text("Uploading done");

                // extract key and generate URL from response
                var key = $(data.jqXHR.responseXML).find("Key").text();
                var url = '//' + url_host + '/' + key;

                // create hidden field
                var input = $("<input />", {type: 'hidden', name: fileInput.attr('name'), value: url})
                form.append(input);
                // $('img#image_id')[0].src = "http:"+url
            },
            fail: function (e, data) {
                submitButton.prop('disabled', false);

                progressBar.
                    css("background", "red").
                    text("Failed");
            }
        });
    }
}

function uploader_unpack() {
    $('input:file.directUpload').each(function (i, elem) {
        uploader_init(elem);
        $(elem).change(function(){
            readURL(this);
        });
    });
}

function readURL(input) {
    if (input.files && input.files[0]) {
        var reader = new FileReader();
        var image = $('img#image_id')[0];

        reader.onload = function (e) {
            image.onerror = function () {

            }
            $(image).attr('src', e.target.result);
        }
        var alt = $(input).val()
        reader.readAsDataURL(input.files[0]);
    }
}
