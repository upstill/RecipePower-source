module UploaderHelper
  def uploader_data decorator, pic_field_description='avatar'
    s3_direct_post = S3_BUCKET.presigned_post(key: "uploads/#{decorator.object.class.to_s.underscore}/#{decorator.id}/${filename}",
                                              success_action_status: 201,
                                              acl: :public_read)
    {
        input_id: pic_preview_input_id(decorator),
        img_id: pic_preview_img_id(decorator),
        form_data: s3_direct_post.fields,
        url: s3_direct_post.url.to_s,
        url_host: s3_direct_post.url.host
    }
  end

  def uploader_field decorator, options={}
    uld = uploader_data(decorator).merge options
    content_tag :input, '',
        class: 'directUpload dialog-button',
        id: 'user_avatar_url',
        label: 'Upload picture...',
        # onload: 'uploader_onload(event);',
        name: decorator.picable_attribute,
        type: 'file',
        data: { direct_upload: uld }
  end

end
