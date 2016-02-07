require "templateer.rb"
class TagDecorator < Draper::Decorator
  include Templateer
  delegate_all

  def title
    object.name
  end

  def self.ref_check fix=false
    Tag.where(tagtype:11).to_a.collect { |tag|
      tag.decorate.ref_check fix
    }.compact
  end

  def ref_check fix=false
    @fix = fix

    def cancel_fix explanation
      if @fix
        puts 'Canceling fix because ' + explanation
        @fix = false
      end
    end

    def cancel_fix_if bool, explanation
      cancel_fix(explanation) if bool
    end

    report = []
    if (expr_ids = Expression.where(tag_id: id).pluck(:id)).present?
      report << "    * referenced in Expression(s) #{expr_ids}"
      expr_ids.each { |expr_id|
        expr = Expression.find(expr_id)
        cancel_fix_if (expr.referent && expr.referent.type != 'ChannelReferent'), 'used in Expression for non-Channel referent'
        report[-1] << "Ref #{expr.referent_id} #{'not' unless expr.referent_id && Referent.find_by_id(expr.referent_id)} good."
      }
    end
    if (l = List.where(name_tag_id: id).pluck(:id)).present?
      report << "    * referenced in List(s) #{l}"
      cancel_fix 'used as title of list'
    end
    channel_referent = nil
    if (l = dependent_referents.to_a.collect { |ref|
      if ref.type == 'ChannelReferent'
        channel_referent = ref
      else
        cancel_fix 'used as canonical expression by non-Channel referent'
      end
      ref.type+ref.id.to_s
    }).present?
      report << "    * referenced in Referent(s) #{l.join(', ')}"
    end
    corresponding_list = (matcher = Tag.where(name: tag.name, tagtype: 16).first) &&
        (List.where(name_tag_id: matcher.id).first) unless channel_referent
    if (l = Tagging.where(tag_id: id).pluck(:id)).present?
      cancel_fix_if !(channel_referent || corresponding_list), 'tagging not in the presence of a ChannelReferent'
      report << "    * referenced in tagging(s) #{l}"
    end
    if (l = TagOwner.where(tag_id: id).pluck(:id)).present?
      report << "    * referenced in TagOwner(s) #{l}"
    end
    if (l = TagSelection.where(tag_id: id).pluck(:id)).present?
      report << "    * referenced in TagSelection(s) #{l}"
      cancel_fix 'referenced in TagSelection(s)'
    end
    tc_entities = taggings.map &:entity
    if corresponding_list ||= (List.assert(name, User.find(1), create: true) if tc_entities.present? && channel_referent)
      report << "    * matches list ##{corresponding_list.id} (#{corresponding_list.name}) w. tag ##{corresponding_list.name_tag_id}"
      tc_entities = tc_entities - corresponding_list.entities
    end
    tc_entities.each { |missing|
      descrip =
          if @fix && corresponding_list
            corresponding_list.store missing
            'moved from Channel to List'
          else
            "tagged in #{channel_referent ? 'Channel' : 'Tagging'} but not List"
          end
      report << "#{missing.class.to_s} ##{missing.id}(#{missing.decorate.title}) #{descrip}"
    }
    report << '...all taggings are duplicated in list' if taggings.present? && tc_entities.empty?
    if report.present?
      report = ["-----------------", "#{name}(#{id}): "] + report
    else
      report = ["-----------------", "#{name}(#{id}) is unreferenced. "]
    end
    puts report.join("\n")
    if @fix # An unreferenced tag is good to delete
      puts "Destroying tag ##{tag.id}"
      tag.destroy
      nil
    else
      self
    end
  end

end
