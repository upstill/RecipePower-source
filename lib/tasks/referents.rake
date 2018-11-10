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

    # Identify a circularity arising from the path
    # -- path is an array proceeding from element to parent
    # -- map gives the parents for each referent. Ids index lists of ids
    def circular_path path, map
      # We'll check the last id on the path against each of its parents
      if parent_ids = map[path.last]
        parent_ids.each { |parent_id|
          if path.include? parent_id
            return path[path.index(parent_id)..-1] << parent_id
          elsif circle = circular_path(path + [parent_id], map)
            return circle
          end
        }
        nil
      end

    end

    # Build a table giving the parents for each referent
    map = []
    ReferentRelation.all.pluck(:child_id, :parent_id).each { |pair|
      (map[pair.first] ||= []) << pair.last
    }
    map.each_with_index do |parents, id|
      if parents && (path = circular_path [id], map)  # Let higher loops be reported directly
        puts "Circular parentage found for Referent ##{id} (#{Referent.find(id).name}):"
        ellipsis = 'Beginning'
        puts path.reverse.collect { |id|
               report = "  #{ellipsis} Referent ##{id} (#{Referent.find(id).name})"
               ellipsis = '...has child'
               report
             }
      end
    end
    if rr = ReferentRelation.find_by( parent_id: 5222, child_id: 5036 )
      rr.destroy
    end
  end

end
