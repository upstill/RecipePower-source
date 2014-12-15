module UploaderHelper
  def uploader_data pic_field_name=:picurl, pic_field_description="avatar"
    s3_direct_post = S3_BUCKET.presigned_post(key: "uploads/#{@decorator.object.class.to_s.underscore}/#{@decorator.id}/${filename}",
                                              success_action_status: 201,
                                              acl: :public_read)
    {
        input_id: pic_preview_input_id(@decorator, pic_field_name),
        img_id: pic_preview_img_id(@decorator),
        form_data: s3_direct_post.fields,
        url: s3_direct_post.url.to_s,
        url_host: s3_direct_post.url.host
    }
  end

  def uploader_field fieldname
    content_tag :input, "",
        class: "directUpload",
        id: "user_avatar_url",
        label: "Upload picture...",
        name: fieldname, # @decorator.field_name(fieldname),
        type: "file",
        data: { direct_upload: uploader_data }
  end

end