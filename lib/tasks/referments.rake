namespace :referments do
  desc "Manage the Referments class"

  # Make referments polymorphic by changing all Referent types to 'Referent'
  task :polymorphosize => :environment do
    typenames = %w{
      SourceReferent
      InterestReferent
      GenreReferent
      RoleReferent
      DishReferent
      CourseReferent
      ProcessReferent
      IngredientReferent
      AuthorReferent
      OccasionReferent
      PantrySectionReferent
      StoreSectionReferent
      DietReferent
      ToolReferent
      NutrientReferent
      CulinaryTermReferent
      QuestionReferent
      ListReferent
      EpitaphReferent
      CourseReferent
      TimeReferent
    }
    Referment.where(referee_type: typenames).each { |rfm|
      rfm.update_attribute :referee_type, 'Referent'
    }
  end

  # Remove redundant referments, i.e. those with identical referent and referee
  task :purge => :environment do
    specs = Referment.all.pluck :referent_id, :referee_id, :referee_type
    counts = {}

    specs.each { |spec|
      specstr = spec.map(&:to_s).join ';'
      counts[specstr] ||= 0
      counts[specstr] += 1
    }
    puts "#{specs.count} extracted"
    puts "#{counts.count} unique"
    counts = counts.keep_if { |key, val|
      if val > 1
        puts "#{key}: #{val}"
        true
      else
        false
      end
    }
    puts "#{counts.count} redundant"
    counts.each { |key, val|
      terms = key.split ';'
      spec = {
          :referent_id => terms.first.to_i,
          :referee_id => terms[1].to_i,
          :referee_type => terms.last
      }
      rfms = Referment.where(spec).to_a
      rfms.pop
      while(rfm = rfms.pop)
        rfm.destroy
      end
    }
  end

end
