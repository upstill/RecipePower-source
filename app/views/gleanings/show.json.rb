decorator = @gleaning.entity.decorate
{
    replacements: [
        gleaning_field_replacement(decorator, :titles),
        gleaning_field_replacement(decorator, :descriptions),
        gleaning_field_replacement(decorator, :feeds)
    ]
}.to_json