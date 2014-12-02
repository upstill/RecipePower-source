flash[:alert] = express_resource_errors(@list) unless @list.errors.empty?
flash_notify.to_json