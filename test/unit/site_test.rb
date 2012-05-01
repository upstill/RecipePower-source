# encoding: UTF-8
require 'test_helper'
class SiteTest < ActiveSupport::TestCase 
    fixtures :sites
    
    test "sample parses out correctly" do
        nytsample = sites(:nyt).sample
        site = Site.create(sample: nytsample)
        assert_equal sites(:nyt).site, site.site, "Incorrect site from sample '#{nytsample}'"
    end
    
    test "Same sample maps to same site" do
        alcasample = "http://www.alcademics.com/2012/04/a-brilliant-idea-that-didnt-quite-work.html?utm_source=feedburner&utm_medium=feed&utm_campaign=Feed%3A+Alcademics+%28alcademics.com%29"

        site1 = Site.by_link(alcasample)
        site2 = Site.by_link(alcasample)
        assert_equal site1, site2, "Same sample creates different sites"
    end

    test "Different samples from one site map to same site" do
        alcasample = "http://www.alcademics.com/2012/04/a-brilliant-idea-that-didnt-quite-work.html?utm_source=feedburner&utm_medium=feed&utm_campaign=Feed%3A+Alcademics+%28alcademics.com%29"
        site1 = Site.by_link(alcasample)
        alcasample = "http://www.alcademics.com/2012/04/the-golden-gate-75-cocktail-.html?utm_source=feedburner&utm_medium=feed&utm_campaign=Feed%3A+Alcademics+%28alcademics.com%29"
        site2 = Site.by_link(alcasample)
        assert_equal site1, site2, "Different samples from one site creates different sites"
    end

end