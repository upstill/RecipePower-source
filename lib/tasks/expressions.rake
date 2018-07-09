namespace :expressions do
  desc "Manage the library of expressions"

  def gather_mismatches
    Expression.includes(:referent, :tag).reject do |expr|
      !(expr.tag && expr.referent) || (expr.tag.typename == expr.referent.typename)
    end
  end

  # Report on expressions with bogus tags
  task report: :environment do
    # Scan every expression in the database and return those with a bogus tag
    bogus = Expression.includes(:tag).reject { |expr|  expr.tag }
    if bogus.empty?
      puts 'No bad expressions found'
    else
      puts '#{bogus.count} bad expressions found'
      bogus.each { |expr|
        puts "Nil tag for #{expr.class.to_s} ##{expr.id} to tag ##{expr.tag_id}"
      }
    end

    mm = gather_mismatches
    if mm.empty?
      puts 'No expressions found relating mismatched tag and referent'
    else
      puts 'Expressions found relating mismatched tag and referent'
      mm.each { |expr|
        puts "#{expr.id}: #{expr.tag.typename} Tag (##{expr.tag.id}--#{expr.tag.name}) doesn't match #{expr.referent.typename} (##{expr.referent.id})"
      }
    end
  end

  # Repair expressions with a bogus tag by asking the associated referent to replace the tag.
  # This has the effect of removing the expression.
  task repair: :environment do
    bogus = Expression.includes(:tag).reject { |expr| expr.tag }
    puts "#{bogus.count} bogus expressions found"
    bogus.each { |expr|
      puts "Fixing #{expr.class.to_s} ##{expr.id}"
      ref = expr.referent
      tag = expr.tag
      if expr.referent
        expr.referent.drop expr.tag_id
      else
        expr.destroy
      end
      tag.reload if tag
      ref.reload if ref
    }
  end
end
