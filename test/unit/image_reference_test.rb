# encoding: UTF-8
require 'test_helper'
class ImageReferenceTest < ActiveSupport::TestCase
  fixtures :referents
  fixtures :tags

  test 'image reference gets joined properly' do
    site = Site.find_or_create_for 'http://www.dailybitesblog.com/'
    site.bkg_land
    assert site.good?
    refute site.errors.any?
    gl = site.gleaning
    # assert gl.good?, 'Gleaning isn\'t born good'
    gl.images.each { |img|
      assert img.match(/^http/), "relative image path #{img}"
    }
  end

  test 'image reference with valid URL yields it as imgurl' do
    url = "http://img.rasset.ie/000675cb-1600.jpg"
    ir = ImageReference.create url: url
    assert_equal url, ir.imgurl, "doesn't duplicate URL in imgurl"
  end

  test 'image reference loads thumbnail onto aws' do
    ir = ImageReference.create url: ImageReference.fake_url
    ir.thumbdata = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAdAAAACGCAYAAABt/dteAAAcmklEQVR4Ae2dS6wdxYGG28ZPbOMAJjaeZexAVraDnU2wZDIbGGkmmySMNCycgQWMiEIWIFAmXgQQVliARSSyAMKCSCFBmsBIY2/GINlIowBjsxqI8SZSjAlxCPja1w/MHX0N1S63+1FVXdXd59y/pKPTp089v66uv961YG5ubi6TEQEREAEREAER8CKw0Mu2LIuACIiACIiACOQEJKDKCCIgAiIgAiIQQEACGgBNTkRABERABERAAqo8IAIiIAIiIAIBBCSgAdDkRAREQAREQAQkoMoDIiACIiACIhBAQAIaAE1OREAEREAEREACqjwgAiIgAiIgAgEEJKAB0OREBERABERABCSgygMiIAIiIAIiEEBAAhoATU5EQAREQAREQAKqPCACIiACIiACAQQkoAHQ5EQEREAEREAEJKDKAyIgAiIgAiIQQEACGgBNTkRABERABERAAqo8IAIiIAIiIAIBBCSgAdDkRAREQAREQAQkoMoDIiACIiACIhBAQAIaAE1OREAEREAEREACqjwgAiIgAiIgAgEEJKAB0OREBERABERABCSgygMiIAIiIAIiEEBAAhoATU5EQAREQAREQAKqPCACIiACIiACAQQkoAHQ5EQEREAEREAEJKDKAyIgAiIgAiIQQEACGgBNTkRABERABERAAqo8IAIiIAIiIAIBBCSgAdDkRAREQAREQAQkoMoDIiACIiACIhBAQAIaAE1OREAEREAEREACqjwgAiIgAiIgAgEEJKAB0OREBERABERABCSgygMiIAIiIAIiEEBAAhoATU5EQAREQAREYNF8QXDm8JvZ3MzJbGbvy9mF48eybMGC7Iq167Mrt38rW37zjmzhylVTgeLs229l5468k5177908nZ/NnMyvTeJI55INN+Q/F2+4IVu0bn22dPPW4p6xp28REAEREIFmAgvm5ubmmq1M578I6l9+fF/22amZPIGrd96drfrOv0yckCKQswdfy04f2J/Nvv5q8MNCSJfffEv+WbZ5a+7PH3dsdvYPfnxkxkPA5/m5xnpsz/nj53+R8elqxpaurumR+34IjK4FSsvp7OE3M4TBNnnLaeON2dJNN9m3g68RiTWPPpn9+b67cj94CU/teyVb88gTwa2xT379fDb7PweztU8+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"
    assert ir, "Couldn't create ImageReference"
    assert_not_empty (url = ir.imgurl), 'No url returned from imgurl'
    # NB Have no apparent way to compare stored data with original
    # original = ir.thumbdata.sub 'data:image/png;base64,', ''
    # str = ir.fetch(url)
    # fetched = (Base64.encode64 Magick::Image.from_blob(str).first.to_blob).encode 'UTF-8'
    # assert_equal original, fetched, 'Wrong data stored in AWS'
  end

end