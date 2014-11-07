result = { done: true }
result[:popup] = flash_popup if flash_popup(true)
result[:popup] = @popup_msg if @popup_msg
result.to_json