namespace :expressions do
  desc "Manage the library of expressions"

  # Scan every expression in the database and return those with a bogus tag
  def gather_bogus
    bad_exprs = []
    Expression.includes(:tag).all.find_in_batches do |group|
      group.collect { |expr|
        bad_exprs << expr if expr.tag == nil
      }
    end
    bad_exprs
  end

  # Report on expressions with bogus tags
  task report: :environment do
    bogus = gather_bogus
    if bogus.empty?
      puts 'No bad expressions found'
    else
      bogus.each { |expr|
        puts "Nil tag for Expression ##{expr.id} to tag ##{expr.tag_id}"
      }
    end
  end

  # Repair expressions with a bogus tag by asking the associated referent to replace the tag.
  # This has the effect of removing the expression.
  task repair: :environment do
    gather_bogus.each { |expr|
      if expr.referent
        expr.referent.drop expr.tag_id
      else
        expr.destroy
      end
    }
  end
end
