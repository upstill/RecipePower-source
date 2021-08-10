require 'recipe.rb'
require 'recipe_page.rb'
class ParsingServices
  attr_accessor :entity, # The entity in question
                :parsed, # Results after parsing
                :scanned # Results after scanning

  def initialize entity = nil
    self.entity = entity
  end

  # Employ the parser to generate the results:
  # @parsed is from a top-down parse starting with a grammar entry denoted by token.
  # @results is from a scan of the content, looking for tokens that don't appear in the parsed results (as needed).
  # Return: @parsed, which is nil if the parse failed
  def parse content: nil, needed: [:rp_title, :rp_inglist, :rp_serves]
    self.content = content if content.present?
    return nil if @content.blank?

    @parsed ||= parser.match token

    # Perform the scan only if needed elements aren't found in the parse
    @scanned ||= parser.scan if needed.any? { |token| !@parsed&.find(token).first }

    # Report out the ingredient lines
    if Rails.env.test?
      [:rp_ingline].each do |token|
        Rails.logger.debug "-------------- #{token} ---------------"
        results_for(token).each { |skr| Rails.logger.debug skr }
      end
    end

    @parsed
  end

  # Generate a revised version of the content with tags corresponding to the parsing output.
  def annotate
    @parsed.enclose_all parser: parser if @parsed&.success?
    @scanned.enclose_all parser: parser if @scanned&.success?
    (@parsed || @scanned).head_stream.nkdoc.to_s
  end

  # Get all the results for a given token from both the parse and the scan
  def results_for token
    [@parsed&.find(token), @scanned&.find(token)].flatten.compact
  end

  # Using the seeker from the last parse, find the string representing a token value
  def value_for token
    @seeker&.find(token).first&.to_s
  end

  private

  # Attribute writers enforce dependencies
  def entity= e
    if @entity != e
      # A new entity invalidates:
      self.content = e.content
      self.grammar_mods = e.site.grammar_mods
      @entity = e
    end
    @entity
  end

  # Memoize content from entity
  def content
    @content ||= @entity.content
  end

  def content= ct
    if ct != @content
      @parsed = @scanned = nil
      @content = ct
    end
    @content
  end

  # Grammar mods associated with the entity's site
  def grammar_mods
    @grammar_mods ||= @entity&.site&.grammar_mods
  end

  def grammar_mods= gm
    if gm != @grammar_mods
      self.parser = nil
      @grammar_mods = gm
    end
    @grammar_mods
  end

  def parser
    @parser ||= Parser.new content, grammar_mods
  end

  def parser= p
    if p != @parser
      # Clear ivars derived from the parser
      @parsed = @scanned = nil
      @parser = p
    end
    @parser
  end

  def token
    @token ||=
        case @entity
        when Recipe
          :rp_recipe
        when RecipePage
          :rp_recipelist
        end
  end

  # Provide a path and offset in the Nokogiri doc for the results of the parse
  def xbounds
    @seeker ? [@seeker.head_stream.xpath, @seeker.tail_stream.xpath(true)] : []
  end

end
