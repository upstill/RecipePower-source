flash[:alert] = express_resource_errors(@list) unless @list.errors.empty?
{
    replacements: [ list_menu_item_replacement(@list, @entity, params[:styling]) ]
}.merge(flash_notify).to_json