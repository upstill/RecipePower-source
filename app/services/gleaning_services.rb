class GleaningServices
  def self.completed_gleaning_for url_or_pagerefable, *labels
    page_ref = url_or_pagerefable.is_a?(String) ? PageRef.fetch(url_or_pagerefable) : url_or_pagerefable.page_ref
    gleaning = page_ref.gleaning || page_ref.build_gleaning
    gleaning.needs = labels
    gleaning.bkg_land
    gleaning
  end
end