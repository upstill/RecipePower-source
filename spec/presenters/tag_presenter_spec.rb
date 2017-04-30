require 'rails-i18n'
require TagPresenter

describe TagPresenter do
  fixtures :tags
  fixtures :referents
  fixtures :expressions

  before do
    load_rails_i18n :fr
    I18n.default_locale = :fr

    @presenter = FastPresenter.new 10
  end

  it "decorates as a percentage
          with 2 digits after the decimal separator (locallized!)" do
    expect(@presenter.decorate).to eq("10,00%")
  end

  # Helpers: move these to a support file
  def load_rails_i18n(pattern)
    RailsI18n::Railtie.add("rails/locale/#{pattern}.yml")
    RailsI18n::Railtie.add("rails/pluralization/#{pattern}.rb")
    RailsI18n::Railtie.add("rails/transliteration/#{pattern}.{rb,yml}")

    RailsI18n::Railtie.init_pluralization_module
  end

  def load_rails_app_config_locales
    # /!\ RAILS root is a relative path
    rails_root = Pathname.new(File.expand_path("../../..", __FILE__))
    I18n.load_path += Dir[rails_root.join('config', 'locales', '*.{rb,yml}')]
  end

end
