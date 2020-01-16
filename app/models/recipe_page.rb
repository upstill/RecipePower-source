class RecipePage < ApplicationRecord
  include Backgroundable
  backgroundable

  mass_assignable_attributes :content

  has_one :page_ref
  has_many :recipes, :through => :page_ref
  accepts_nested_attributes_for :recipes

  # The page performs by parsing the content from its page_ref
  def perform
    if content.blank?
      # Need to get content from page_ref before we can do anything
      if page_ref # Finish doing any necessary gleaning of the page_ref
        page_ref.bkg_land
        if page_ref.good?
          self.content = SiteServices.new(page_ref.site).trim_recipe page_ref.content
        else
          err_msg = "Page at '#{url}' can't be gleaned: PageRef ##{page_ref.id} sez:\n#{page_ref.error_message}"
          errors.add :url, err_msg
          raise err_msg if page_ref.dj # PageRef is ready to try again => so should we be, so restart via Delayed::Job
        end
      end
    end

    # Now we presumably have valid content. Now to parse it.
    parse if content.present?
    save
  end

  def parse

  end

end
