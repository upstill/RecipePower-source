{ dlog: with_format("html") {
    render( "pic_picker", picurl: params[:picurl], pageurl: params[:pageurl], golinkid: params[:golinkid] )
}
}.to_json