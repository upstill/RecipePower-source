class ReferentServices
  
  def initialize(referent)
    @referent = referent
  end
  
  # Return the ids of referents directly descended from those given (as an id or ids)
  def self.direct_child_ids(ref_id_or_ids)
    ReferentRelation.where(parent_id: ref_id_or_ids).pluck(:child_id) - [ref_id_or_ids].flatten
  end
  
  def self.direct_parent_ids(ref_id_or_ids)
    ReferentRelation.where(child_id: ref_id_or_ids).pluck(:parent_id) - [ref_id_or_ids].flatten
  end

  # Return the ontological parentage from one referent id to another, if such a path exists
  # Result: an ordered array of referents, higher to lower in the hierarchy (i.e, starting with other and ending with self)
  def self.id_path path, higher_id
    if path.last == higher_id # Found!
      return path
    elsif path.include?(higher_id) # No cycles, please
      return nil
    else
      # Try each parent id in turn to see if it completes a path
      self.direct_parent_ids(path.last).inject(nil) { |result, parent_id|
        result || self.id_path(path << parent_id, higher_id)
      }
    end
  end

  # Provide an array of referents denoting the lineage from 'other' to this referent
  def ancestor_path_to other
    if path = ReferentServices.id_path([@referent.id], other.id)
      path.collect { |rid|
        case rid
          when @referent.id
            @referent
          when other.id
            other
          else
            Referent.find_by id: rid
        end
      }
    end
  end

=begin
  # Return the transitive closure of the referent's ancestors
  def ancestor_ids &block
    newset = @referent.parent_ids
    ancestor_ids = []
    while newset.present? do
      ancestor_ids |= newset
      newset = ReferentRelation.where(child_id: newset).pluck :parent_id
      if (circularities = newset & ancestor_ids).present?
        # GAH! Parent(s) appear which have already been checked! Circularity!!!
        if block.present?
          yield @referent, circularities
        else
          newset -= circularities
        end
      end
    end
    return ancestor_ids
  end

  def ancestor_ids!
    ancestor_ids do  |ref, circularities|
      msg = "Ref '#{ref.name}' (#{ref.id}) has circularity in its ancestry with" +
          Referent.where(id: circularities).collect { |ref| "'#{ref.name}' (#{ref.id})" }.join(' and ')
      throw msg
    end
  end
=end

  # Change all canonical-expression uses of the tag at fromid to point to toid
  def self.change_tag(fromid, toid)
    Referent.where(tag_id: fromid).each { |ref| ref.update_attribute :tag_id, toid }
  end

  # The referment params require special processing, since
  # 1) The Kind of a referment may have been changed by the user.
  #     => translate the referee to the target type
  # 2) Each referment may only be specified as a referee (type and id) but not priorly exist
  #     => create the referment anew and include it in the referent's referments
  # 3) It may only be specified as a URL and Kind without priorly existing.
  #     => find or create a PageRef and associated entity
  def parse_referment_params params
    params.each do |index, rfmt_params|
      if (rfmt = Referment.find_by id: rfmt_params[:id]) || (rfmt_params[:_destroy] || '') == '1'
        @referent.referments.destroy rfmt if rfmt
      elsif rfmt # First, the simple case: the referment is accessible by id
        @referent.referments << rfmt unless @referent.referment_ids.include? rfmt.id
        # Referment exists => we only have to confirm that the kind parameter matches the referee type
        rfmt.referee = RefereeServices.new(rfmt.referee).assert_kind rfmt_params[:kind]
        rfmt.save if rfmt.changed?
      elsif rfmt_params[:referee_id] &&
          rfmt_params[:referee_type].present? &&
          referee = rfmt_params[:referee_type].constantize.find_by(id: rfmt_params[:referee_id].to_i)
        if referee == @referent
          @referent.errors.add :reference, "can't refer to itself"
          return
        end
        # The referment's referee is accessible => build a new referment for the referent
        # Ensure the type of referee matches the 'kind' parameter
        referee = RefereeServices.new(referee).assert_kind rfmt_params[:kind]
        # The Referment doesn't exist but the referee does => create a new Referment
        # Don't want to add a redundant referment
        if @referent.referments.exists?( referee: referee)
          @referent.errors.add :reference, "already exists"
        end
        rfmt = @referent.referments.build referee: referee
      else
        # There is no extant referment OR referent, but only the kind and url parameters
        rfmt = assert_referment rfmt_params[:kind], rfmt_params[:url]
        if rfmt.errors.any?
          @referent.errors.add :referments, "have bad kind/url #{rfmt_params[:kind]}/#{rfmt_params[:url]}: #{rfmt.errors.full_messages}"
        elsif @referent.referments.exists? referee: referee
          @referent.errors.add :reference, "already exists"
        else
          @referent.referments << rfmt
        end
      end
    end
  end

  # Ensure the existence of a Referment of a particular kind with the given url
  def assert_referment kind, url
    def self.bail attribute, err
      rtn = Referment.new
      rtn.errors.add attribute, err
      rtn
    end
    begin
      uri = URI url
    rescue Exception => e
      # Bad URL or path => Post an error in an unsaved record and return
      return bail(:url, 'is not a viable URL')
    end
    if uri.host.match 'recipepower.com'
      # An internal link, presumably to a Referrable entity
      begin
        hsh = Rails.application.routes.recognize_path uri.path
        controller, id = hsh[:controller], hsh[:id].to_i
        model_class = controller.classify.constantize
        model = model_class.find_by id: id
      rescue Exception => e
        # Bad URL or path => Post an error in an unsaved record
        return bail(:url, 'isn\'t anything viable in RecipePower')
      end
      if @referent.referments.exists? referee: model
        bail :reference, "already exists"
      elsif @referent == model
        bail :reference, "can't have itself as reference"
      elsif model.is_a?(Referrable) || model.is_a?(Referent)
        Referment.new referee: model
      else
        bail :reference, 'isn\'t anything usable from RecipePower'
      end
    else
      # An external link
      if pr = PageRef.fetch(url) # URL produces a viable PageRef
        pr.kind = kind
        Referment.new referee: pr
      else
        bail(:url, 'can\'t be read')
      end
    end
  end


end
