namespace :referents do
  desc "Manage the library of referents"

  def gather_bogus
    Referent.where(tag_id: nil).to_a
  end

  # Report on bogus referents i.e., those without a canonical expression
  # NB: See also the Expressions rake task, which detects bad tags
  task report: :environment do
    if (bogus = gather_bogus).empty?
      puts 'All referents have canonical expression.'
    else
      bogus.each { |ref|
        puts "#{ref.id} (#{ref.type}): #{ref.expressions.count} Expressions: #{ref.expressions.map(&:tagname).join(', ')}"
      }
    end
  end

  # Repair bogus referents, as above, by selecting one of their expressions and using that tag as a canonical expression
  # If the referent no longer has any connections, either in expression, or referments, or other referents, then destroy it
  task repair: :environment do
    gather_bogus.each { |ref|
      ref.drop nil
      # If after trying to secure another expression, all connections to the referent are empty, destroy it
      ref.destroy if ref.detached?
    }
  end

  task circle_check: :environment do
    # Transitively search for a key among the ancestors of the parents
    def path_to path, parent_ids, map
      if parent_ids.present?
        # puts "Check Referent parentage ##{path} with parents #{parent_ids}"
        parent_ids.each { |parent_id|
          if path.include? parent_id
            return path + [parent_id]
          else
            if found = path_to((path + [parent_id]), map[parent_id], map)
              return found
            end
          end
        }
        nil
      end
    end

    # Build a table giving the parents for each referent
    map = []
    ReferentRelation.all.pluck(:child_id, :parent_id).each { |pair|
      map[pair.first] = (map[pair.first] || []) + [pair.last]
    }
    # parent_ids = 5222
    # parent_ids = 4
    map.each_index { |id|
      if (path = path_to([id], map[id], map)) && (path.first == path.last)  # Let higher loops be reported directly
        puts "Circular parentage found for Referent ##{id} (#{Referent.find(id).name}):"
        puts path.map { |id| "    Referent ##{id} (#{Referent.find(id).name})" }
      end
    }
    if rr = ReferentRelation.find_by( parent_id: 5222, child_id: 5036 )
      rr.destroy
    end
  end

  task fix_defrefs: :environment do
    candidate_referments = Referment.where(referee_type: 'Reference')
    candidate_reference_ids = candidate_referments.pluck :referee_id
    definition_reference_ids = Reference.where(id: candidate_reference_ids, type: 'DefinitionReference').pluck :id
    referments = candidate_referments.to_a.keep_if { |rfm| definition_reference_ids.include? rfm.referee_id }
    referments.map &:destroy

    if rfm = Referment.find_by(referee_type: 'Reference', referee_id: 14029)
      rfm.referee = HomepagePageRef.fetch rfm.referee.url
      rfm.save
    end

  end
end
