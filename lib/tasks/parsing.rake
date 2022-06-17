# These tasks export parsing information from the database so it can be imported into another.
# The concern is for Finders that locate content (label == 'Content') and
# the trimmers and grammar_mods of Sites.
# Export is in the form of a block-organized YAML file.
# Each block begins with a line '--- <Class>#<id>', where the Class and id specify a record
# All lines up to the next block-begin line are part of the YAML for that record's attributes.
# The records are sorted by first line, to support diffing for changes
namespace :parsing do
  desc "Export and Import parsing-relevant data out of and into the database"
  # Export fields relevant to parsing
  task export: :environment do
    assertions = {}
    Site.all.pluck(:id, :trimmers, :grammar_mods).each do |tuple|
      id = tuple.shift
      puts "Site ##{id} has grammar_mods=#{tuple.last}" unless tuple.last.empty?
      next if tuple.first.empty? && tuple.last.empty?
      blob = { trimmers: tuple.first, grammar_mods: tuple.last}.compact.to_yaml
      key = blob.sub! '---', "--- Site##{id}"
      assertions[key] = blob
    end
    Finder.where(label: 'Content').each do |f|
      blob = f.attributes.slice('label', 'selector', 'attribute_name', 'site_id').to_yaml
      key = blob.sub! '---', "--- Finder##{f.id}"
      assertions[key] = blob
    end
    File.open("#{Rails.root}/parsexport.txt", 'w+') do |f|
      assertions.keys.sort.each { |key| f.write assertions[key] }
    end
  end

  # Parse a recipe 100 times with and without building the Lexaur each time
  task lex_test: :environment do
    ParserServices.report_on = false
    recipe = Recipe.find 15584
    NestedBenchmark.do_log = true
    NestedBenchmark.measure("Parsing with Lexaur cache ON") do
      100.times.each do |i|
        recipe.request_attributes [:content], overwrite: true
        recipe.perform
      end
    end

    NestedBenchmark.measure("Parsing with Lexaur cache OFF") do
      100.times.each do |i|
        recipe.request_attributes [:content], overwrite: true
        recipe.perform
        Lexaur.bust_cache
      end
    end
  end

  task import: :environment do

    flush_bfr = ->(bfr) {
      return if bfr.blank?
      bfr = bfr.sub /^--- (\w+)#(\d+)/, '---'
      klass, id = $1, $2
      keyvals = YAML.load(bfr)
      if object = klass.constantize.find_by(id: id)
        oldvals = object.attributes
        puts bfr
        keyvals.except(:id).each { |attribute, val|
          oldval = oldvals[attribute.to_s]
          if val == oldval
            puts "'#{attribute}' unchanged"
          else
            puts "Setting #{attribute} from '#{oldval}' to '#{val}'"
          end
          object.write_attribute attribute, val
        }
        object.save
      else # Object doesn't exist; need to create
        puts "----------------------------- Creating new #{klass}: ----------------------------------"
        keyvals.each { |attribute, val| puts "#{attribute}: #{val}" }
        case klass
        when 'Finder'
          Finder.create keyvals.merge(label: 'Content')
        else
          puts "Not enough information to create #{klass}"
        end
      end
    }
    bfr = ''
    File.foreach("#{Rails.root}/parsexport.txt") do |line|
      if line.match(/^---/)
        # Flush the prior buffer, if any
        flush_bfr.call(bfr)
        bfr = line
      else
        bfr << line
      end
    end
    flush_bfr.call bfr
  end
end
