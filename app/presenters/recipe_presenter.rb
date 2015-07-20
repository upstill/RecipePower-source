class RecipePresenter < CollectiblePresenter

    def card_homelink options={}
      (data = (options[:data] || {}))[:report] = h.polymorphic_path [:touch, @decorator.object]
      link_to @decorator.title, @decorator.url, options.merge(data: data)
      # link_to_submit @decorator.title, @decorator.object, options.merge(:mode => :partial, :data => data)
    end
end
