module SpritesHelper
  require './lib/css_utils.rb'

  def sprite what, options={}
    what = what.to_sym
    vb =
        case what
          when :plus
            "0 0 500 500"
          when :check
            "500 0 500 500"
          when :minus
            "0 600 400 400"
          when :chef
            "1000 0 500 500"
          when :"list-list"
            "500 600 375.0 500"
          when :"list-add"
            "1000 600 375.0 500"
          when :"heart-friend"
            "0 1240 500 500"
          when :"heart-heart"
            "500 1240 500 500"
          when :"heart-add"
            "1000 1240 500 500"
          when :"edit-gray"
            "0 1870 500 500"
          when :"edit-red"
            "500 1870 500 500"
          when :tag
            "1000 1870 500 500"
          when :"vote-up"
            "0 2505 375.0 500"
          when :upload
            "955 2505 500 500"
          when :"vote-down"
            "0 3105 375.0 500"
          when :share
            "500 3105 500 500"
          when :"send-left"
            "1000 3105 500 500"
          else
            return nil
        end
    ip = image_path "recipe-power-sprite.svg##{what}"
    wid, height = vb.split(' ')[2..3].map(&:to_f)
    ar = wid/height
    if options[:width] || options[:height]
      # dim_scale won't scale percentages or 'auto', returning nil and thus preventing
      options[:width] ||= dim_scale(options[:height], ar)
      options[:height] ||= dim_scale(options[:width], 1/ar)
    else
      options[:height] = '100%' # Fit into enclosing div
    end
    content_tag :svg,
                tag(:use, :'xlink:href' => ip),
                options.slice(:width, :height).merge(id: what, viewBox: vb).compact
  end

  # Insert a sprite glyph
  # what: one of the symbols taken by sprite()
  # size (if given): "xs", "sm", "lg", "xl"
  def sprite_glyph what, size=nil, options={}
    if size.is_a? Hash
      size, options = nil, size
    end
    options[:class] = "#{options[:class]} sprite-glyph"
    options[:class] << " sprite-glyph-#{size}" if size
    content_tag :div, sprite(what), options
  end

end
