module TokenInputHelper
  require 'rack'

  # Provide a text field that will be used by tokeninput
  # -- name: the name and id that the text element will have
  # -- querytags: either a scope or an array of tags to initialize with
  # -- tagtype: if provided, a string specifying a set of tag types to match against (default: all types)
  # -- options[:handler] should be either 'querify' or 'submit' (the default)
  # -- otherwise, options are documented below.
  # The 'data' hash specifies the options passed in the 'data' field to tokeninput
  # The 'option_defaults' and 'option_overrides' hashes assert required options for text_field_tag
  # All other options are passed to text_field_tag
  def token_input_tag name, querytags=[], opt_params={}
    querytags, opt_params = [], querytags if querytags.is_a?(Hash)
    options = opt_params.dup # Keepin' it immutable!

    def convert_tagtype tt
      case tt
        when Array
          tt.map { |t| Tag.typenum t }.map(&:to_s).join(',')
        when Symbol
          Tag.typenum(tt).to_s
        else
          tt
      end
    end

    ####### We suss out the tagtype query for matching tags
    query =
        case (q = options.delete(:query))
          when String
            Rack::Utils.parse_query(URI.unescape q)
          when Hash
            q
          when nil
            {}
        end
    if tagtype = convert_tagtype(options.delete :tagtype)
      query[:tagtype] = tagtype
    elsif tagtype_x = convert_tagtype(options.delete :tagtype_x)
      query[:tagtype_x] = tagtype_x
    elsif !(query[:tagtype] || query[:tagtype_x])
      query[:tagtype_x] = Tag.typenum(:List)
    end
    # Set up the tokeninput data
    tokeninput_options = {
        :hint => 'Narrow down the list',
        :placeholder => 'Seek and ye shall find...',
        :minChars => 2,
        :noResultsText => 'No matching tag found; hit Enter to search with text',
        # JS for how to invoke the search on tag completion:
        # querify (tagger.js) for standard tag handling;
        # submit (tagger.js) for results enclosures (which maintain and accumulate query data)
        :onAdd => options[:handler] || 'submit',
        :onDelete => options[:handler] || 'submit',
        # The tag matching query gets parameterized with the acceptable tag types
        :query => query.to_query, # (tagtype ? "tagtype=#{tagtype}" : "tagtype_x=#{tagtype_x}"),
        # The tokeninput starts with the querytags collection, if any
        :pre => querytags.collect { |tag| tag.attributes.slice('id', 'name') }.to_json,
        :tokenLimit => nil,
        :allowFreeTagging => true,
        :allowCustomEntry => true
    }
    # Let any declared options override the defaults above
    tokeninput_options = tokeninput_options.merge(options.slice(*tokeninput_options.keys)).compact

    option_defaults = {
        :onload => 'RP.tagger.onload(event);',
        :rows => 1
    }

    option_overrides = {
        :class => "token-input-field-pending #{options[:class]}",
        # The data parameters need to be made JSON-friendly by converting camelized names to '-' format
        :data => tokeninput_options.inject({}) { |memo, obj|
          memo[obj.first.to_s.underscore.gsub('_', '-')] = obj.last
          memo
        }
    }

    text_field_tag name,
                   querytags.map(&:id).join(','),
                   option_defaults.merge(options.except(:handler, *tokeninput_options.keys)).merge(option_overrides)
  end

  def token_input_element name, querytags=[], options={}
    content_tag :div,
                token_input_tag(name, querytags, options),
                class: 'token-input-elmt'
  end

end