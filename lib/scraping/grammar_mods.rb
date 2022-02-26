# This module folds grammar modifications (typically as specified in a Site) into the standard parsing grammar
# The only public method is #finalized_grammar, which takes a (the) grammar, incorporates grammar modifications
# specified in mods_plus (see below), and returns a final grammar suitable for driving parsing.
# NB: #finalized_grammar also takes a block, which will be called with
module GrammarMods
  # Revise the default grammar by specifying new bindings for tokens
  # 'grammar_mods' is a hash, typically associated with a Site:
  # -- keys are :rp_* tokens in the grammar (OR high-level :gm_* instructions for generating mod entries)
  # -- values are hashes to be merged with the existing entries (OR parameters for the modifier)
  module ClassMethods

    @@ExclusiveOptions = [ # Each group of options is exclusive: at most one from each group can be declared
        %i{ bound terminus }, # :bound and :terminus are exclusive options
        %i{ atline inline },  # :atline and :inline are exclusive options
        %i{ in_css_match at_css_match after_css_match } # :in_css_match, :at_css_match and :after_css_match are exclusive options
    ]
    def finalized_grammar grammar: Parser.initialized_grammar, mods_plus: {}

      def self.processed_mods mods_plus
        def self.selector_for tag = '', options={}
          return options[:selector] if options[:selector].present?
          if options[:css_class].present?
            # We allow ','-separated classes which should be independently expressed, each with the tag
            return options[:css_class].split(/,\s/).collect { |cl| tag + '.' + cl }.join ', '
          else
            return tag
          end
        end
        grammar_mods = {}
        if mods_plus
          # Start by mapping high-level modification tags into actual mods
          # The :gm_* flags in grammar modifications provide high-level modifications for different purpose.
          # They're effectively macro modifications of the grammar.
          # Each :gm_* key MAY have a value to parametrize it
          # Copy actual grammar entries
          mods_plus.keys.find_all { |key| key.to_s.match /^rp_/ }.each { |key| grammar_mods[key] = mods_plus[key] }
          # Expand :gm_bundle meta-mod(s)
          case mods_plus.delete(:gm_bundles)
          when :wordpress
            grammar_mods[:rp_instructions] = {:in_css_match => "div.wprm-recipe-instruction-group"}
            grammar_mods[:rp_prep_time] = {:in_css_match => 'div.wprm-recipe-prep-time-container'}
            grammar_mods[:rp_cook_time] = {:in_css_match => 'div.wprm-recipe-cook-time-container'}
            grammar_mods[:rp_total_time] = {:in_css_match => 'div.wprm-recipe-total-time-container'}
            grammar_mods[:rp_yields] = {:in_css_match => 'div.wprm-recipe-servings-container'}
            mods_plus[:gm_inglist] = {
                :flavor => :unordered_list,
                :list_class => "wprm-recipe-ingredients",
                :line_class => "wprm-recipe-ingredient"
            }
          end
          # Apply meta-mods
          mods_plus.keys.find_all { |key| key.to_s.match /^gm_/ }.each do |key|
            params, val = {}, mods_plus[key]
            params, val = val, val.delete(:flavor) if val.is_a?(Hash)
            case key.to_sym
            when :gm_inglist
              case val.to_sym
              when :unordered_list
                # params:
                # list_class: css class of the 'ul' tag for an ingredient list
                list_selector = params[:list_selector] || selector_for('ul', css_class: params[:list_class])
                grammar_mods[:rp_inglist] = { :in_css_match => list_selector } # { :or => [ { :in_css_match => list_selector } ] }

                # line_class: css class of the 'li' tags for ingredient lines
                line_selector = params[:line_selector] || selector_for('li', css_class: params[:line_class])
                grammar_mods[:rp_ingline] = { :in_css_match => line_selector }
              when :inline # Process an ingredient list that's more or less raw text, using only ',', 'and' and 'or' to delimit entries
                grammar_mods[:rp_inglist] = {
                    :match => :rp_ingline, # Remove the label spec
                    :orlist => :predivide  # Divide the text up BEFORE passing to the ingredient line match
                }
              when :paragraph
                # grammar_mods[:rp_inglist] = { :in_css_match => selector_for('p', params ) }
                grammar_mods[:rp_inglist] = { :in_css_match => selector_for('p', params ), :enclose => false }
                grammar_mods[:rp_ingline] = { :in_css_match => nil, :inline => true } # , :enclose => false }
              end
            end
          end
        end
        grammar_mods
      end
      def cleanup_entry token, entry
        return {} if entry.nil?
        return entry.map { |subentry| cleanup_entry token, subentry } if entry.is_a?(Array)
        # Convert a reference to a Seeker class to the class itself
        return entry.constantize if entry.is_a?(String) && entry.match(/Seeker$/)
        # return entry if entry.is_a?(String) && entry.match(/Seeker$/)
        return entry unless entry.is_a?(Hash)
        # Syntactic sugar: these flags may specify the actual match. Make this explicit
        [
            :checklist, # All elements must be matched, but the order is unimportant
            :or, # The list is taken as an ordered set of alternatives, any of which will match the list
            :filter, # Like :or, but all matching elements are retained
            :repeating, # The spec will be matched repeatedly until the end of input
            # :orlist, # The item will be repeatedly matched in the form of a comma-separated, 'and'/'or' terminated list
            # :accumulate, # Accumulate matches serially in a single child
            :optional, # Failure to match is not a failure
            :trigger,
            :distribute
        ].each do |flag|
          if entry[flag] && entry[flag] != true
            if flag == :trigger
              entry[:match] ||= entry[:trigger] # The trigger is assumed to be the match unless otherwise specified
              entry.delete :trigger
              # If the trigger is an array, assume that any member will match
              entry[:or] = true if entry[:match].is_a?(Array)
            else
              entry[:match] = entry[flag]
              entry[flag] = true
            end
          end
        end
        entry[:match] = cleanup_entry :match, entry[:match] if entry[:match]
        keys = entry.keys.map &:to_sym # Ensure all keys are symbols
        @@ExclusiveOptions.each do |flagset|
          # At most one of the flags in the flagset can be non-nil
          setflags = (entry.slice *flagset).compact # Eliminating the nil flags
          if setflags.count > 1
            wrongstring = ':' + setflags.keys.map(&:to_s).join(', :')
            flagstring = ':' + flagset.map(&:to_s).join(', :')
            raise "Error: grammar entry for #{token} has #{wrongstring} flags. (Only one of #{flagstring} allowed)."
          end
        end
        entry
      end # cleanup_entry
      # Do
      def merge_entries original, mod
        return original unless mod && mod != {}
        return mod unless original&.is_a?(Hash)
        mod.each do |key, value|
          case value
          when nil?
            original.delete key
          when Hash
            original[key] = merge_entries(original[key], value)
          when Array
            # Merge the two arrays
            value.each_index { |ix| original[key][ix] = merge_entries(original[key][ix], value[ix]) }
          else
            original[key] = value
            # Enforce exclusive options by removing the other members of the set in which the key appears (if any)
            @@ExclusiveOptions.each { |set|
              (set - [key]).each { |keyout| original.delete keyout } if set.include? key
            }
          end
        end
        original
      end
      def do_trigger grammar_entry, &block
        case grammar_entry
        when Hash
          if grammar_entry[:trigger]
            grammar_entry[:match] ||= grammar_entry[:trigger]
            block.call grammar_entry.delete(:trigger)
          elsif match = grammar_entry.slice(:match, :checklist, :or, :filter, :repeating, :distribute, :optional).values.first
            do_trigger match, &block
          end
        when Array
          grammar_entry.find_all { |elmt| do_trigger(elmt, &block) } # rtnval = do_trigger(elmt, &block); return rtnval if rtnval }
        end
      end
      # We need to augment the triggers found in a grammar entry
      # with any found in the grammar_mods, while attending to any
      # explicitly declared in grammar_mods[:triggers]
      def do_triggers grammar_entry, grammar_mods, triggers, key
        # do_trigger finds the trigger in a grammar entry (or mod), calling a block to modify it
        trigger = (triggers[key] if triggers) || []
        do_trigger(grammar_entry) { |extant_trigger| trigger = [trigger, extant_trigger].flatten }
        do_trigger(grammar_mods[key]) { |extant_trigger| trigger = [trigger, extant_trigger].flatten }
        trigger
      end

      # Nicify the prior grammar and the mods, and extract triggers
      grammar_mods = processed_mods( YAML.load mods_plus.to_yaml) # Use YAML to make a deep copy

      puts "Finalising #{grammar.keys.count} grammar entries" if Rails.env.test?
      grammar.each do |key, original|
        # Triggers embedded in the grammar need to be:
        # 1) pulled out for scanning, and
        # 2) modified to include the declared trigger (if any)
        if block_given? && (trigger = do_triggers(original, grammar_mods, grammar_mods[:triggers], key)).present?
          yield key, trigger
        end
        cleaned_up = cleanup_entry key, original # Allows elements to be removed
        grammar[key] =
            if grammar_mods && (mod = cleanup_entry key, grammar_mods[key]).present?
              merge_entries cleaned_up, mod
            else
              cleaned_up
            end
        if Rails.env.test? # Report on the grammar before plunging in
          if grammar[key] == original
            puts ":#{key} unchanged"
          else
            puts "#{mod.present? ? 'Modifying' : 'Finalising' } grammar entry for :#{key}:", indent_lines(original)
            if mod.present?
              puts "  Cleaned:", indent_lines(cleaned_up) if cleaned_up != original
              puts "  Modifier:", indent_lines(mod)
            end
            puts "  Final (#{mod.present? ? 'after' : 'no'} mod): ", indent_lines(grammar[key])
          end
        end
      end
      grammar
    end
  end

  def self.included(base)
    base.extend(ClassMethods)
  end
end