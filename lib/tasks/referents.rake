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
