{
    dlog: with_format("html") {
      render("pic_picker",
             picdata: @picdata,
             picurl: @picurl,
             pageurl: @pageurl,
             fallback_img: @fallback_img,
             golinkid: @golinkid)
    }
}.to_json