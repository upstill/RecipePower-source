// Cribbed from http://h3manth.com/content/download-images-nodejs
// Gather the images from a page
function getImages(uri) {
    var request = require('request');
    var url = require('url');
    var cheerio = require('cheerio');
    path = require('path')
    var fs = require('fs');
 
    request(uri, function (error, response, body) {
        if (!error && response.statusCode == 200) {
            $ = cheerio.load(body)
            imgs = $('img').toArray()
            console.log("Downloading...")
            imgs.forEach(function (img) {
                console.log(img.attribs.src)
                process.stdout.write(".");
                img_url = img.attribs.src
                if (/^https?:\/\//.test(img_url)) {
                    img_name = path.basename(img_url)
                    request(img_url).pipe(fs.createWriteStream(img_name))
                }
            })
            console.log("Done!")
        }
    })
}
