module SpritesHelper
  def sprite what, options={}
    what = what.to_sym
    vb, color =
        case what
          when :plus
            ["0 0 500 500", "#FF9583"]
          when :check
            ["500 0 500 500", "#FF9583"]
          when :chef
            ["1000 0 500 500", "#DFCA6A"]
          when :"list-viewer"
            ["0 600 375.0 500", "#ECDAD7"]
          when :"list-list"
            ["500 600 375.0 500", "#9DBFAA"]
          when :"list-add"
            ["1000 600 375.0 500", "#FF9583"]
          when :"heart-friend"
            ["0 1240 500 500", "#DFCA6A"]
          when :"heart-heart"
            ["500 1240 500 500", "#CC8475"]
          when :"heart-add"
            ["1000 1240 500 500", "#FF9583"]
          when :"edit-gray"
            ["0 1870 500 500", "#A0A0A0"]
          when :"edit-red"
            ["500 1870 500 500", "#CC8475"]
          when :tag
            ["1000 1870 500 500", "#A0A0A0"]
          when :"vote-up"
            ["0 2505 375.0 500", "#ECE6CD"]
          when :upload
            ["955 2505 500 500", "#A0A0A0"]
          when :"vote-down"
            ["0 3105 375.0 500", "#ECE6CD"]
          when :share
            ["500 3105 500 500", "#DFCA6A"]
          when :"send-left"
            ["1000 3105 500 500", "#CCC"]
        end
    ip = image_path "recipe-power-sprite.svg##{what}"
    wid, height = vb.split(' ')[2..3].map(&:to_i)
    content_tag :svg,
                "<use xlink:href='#{ip}'/>".html_safe,
                id: what,
                width: 75*wid/height,
                height: 75,
                viewBox: vb
                # style: "color: #{color}; fill: #{color}"
  end

end