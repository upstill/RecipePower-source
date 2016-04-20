decorator = @gleaning.entity.decorate
{
    replacements: [
        gleaning_field_replacement(decorator, 'Title'),
        gleaning_field_replacement(decorator, 'Description'),
        gleaning_field_replacement(decorator, 'RSS Feed')
    ]
}.to_json