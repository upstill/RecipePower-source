module SitesHelper

  def show_sample(site)
    link_to 'Sample', site.sample
  end

  def site_similars site
    safe_join SiteServices.new(site).similars.collect { |other|
      [
          button_to_submit( "Merge into ##{other.id} '#{other.home}'", absorb_site_path(other, other_id: site.id), :method => :post, :button_size => "sm"),
          button_to_submit( "Absorb ##{other.id} '#{other.home}'", absorb_site_path(site, other_id: other.id), :method => :post, :button_size => "sm")
      ] if site.id != other.id
    }.compact.flatten
  end


  def site_nuke_button site, options={}
    options = {
        button_style: 'danger',
        button_size: 'xs',
        method: 'DELETE'
    }.merge options
    SiteServices.new(site).nuke_message link_to_submit('DESTROY', site, options)
  end

  def site_glean_button site, options={}
    options = {
        button_size: 'xs' #, method: 'POST'
    }.merge options
    link_to_submit('GLEAN', glean_site_path(site, :what => :table, :force => true), options)
  end

  def site_pagerefs_summary site, options={}
  end

  def site_feeds_summary site
  end

  # Summarize a site for the site's table entry
  def site_summaries site, admin_view
    napproved = site.approved_feeds.size
    nothers = site.feeds.size - napproved
    q = labelled_quantity(napproved, 'feed').capitalize
    link = (napproved == 1) ?
        feed_path(site.approved_feeds.first) :
        feeds_site_path(site, response_service.admin_view? ? {:item_mode => :table} : {})
    feed_summary = content_tag(:b, link_to_submit(q, link)) +
        " approved (#{labelled_quantity(nothers, 'other').downcase})".html_safe

    page_refs_summary =
        site.page_refs.group(:kind).count.except(PageRef.kinds[:recipe]).collect { |kind_id, count|
          # site_page_refs_kind_summary site.page_refs.where(kind: kind_id)
          scope = site.page_refs.where kind: kind_id
          report_items(scope, "#{scope.first.kind} page", limit: 5) { |pr| page_ref_identifier pr }
        }.if_present

    set = [feed_summary]
    set << report_items(site.recipes, 'cookmark', limit: 5) { |rcp| homelink rcp, nuke_button: true }
    if admin_view
      set << (site.referent ? referent_summary(site.referent, header: true) : 'No Referent (!!?!)'.html_safe)
      set << "#{site.finders.present? ? 'Has' : 'No'} scraping finders".html_safe
      set << page_ref_identifier(site.page_ref, 'site home page')
      set << page_refs_summary
      set << report_items(site.tags, 'Tagged With', fixed_label: true)

    end
    format_table_tree set.flatten(1)

  end

  # Build a section consisting of a series of elements enclosed and indented.
  # The attribute name refers to both the section and the first item, whose value will dictate what elements
  # are available
  def site_grammar_mod_selector_section site_builder, attribute_name, data, parent_section: nil
    site = site_builder.object
    # Render all dependent fields, showing or hiding them according to to the value of the field
    which_viz = site.grammar_fields.send(attribute_name)&.to_sym
    fields = site.grammar_fields.each_dependent(attribute_name) do |option, declaration|
      content_tag :div,
                  site_grammar_mod_fields(site_builder, section_name: option),
                  class: "#{attribute_name} #{option}",
                  style: 'display: ' + (which_viz == option ? 'block' : 'none') + ';'
    end

    content = site_grammar_mod_field(site_builder, attribute_name, data) +
    content_tag( :div, safe_join(fields.compact), class: "col-md-12") # #{parent_section} #{attribute_name}
  end

  def site_grammar_mod_fields site_builder, section_name: nil
    site = site_builder.object
    selector = site.grammar_fields.send(section_name)&.to_sym if site.grammar_fields.handles? section_name
    fields =
        site.grammar_fields.each_dependent section_name do |option, declaration, rendering_data|
          next unless rendering_data
          if rendering_data[:type] == :select
            site_grammar_mod_selector_section site_builder, option, rendering_data, parent_section: section_name
          else
            site_grammar_mod_field site_builder, option, rendering_data
          end
        end
    result = safe_join fields.compact
    result
  end

  def site_grammar_mod_field site_builder, attribute_name, data
    label = site_builder.label attribute_name, data[:label]
    # Put a :select popup on the same line as the label
    label = safe_join [
                          label,
                          ':  '.html_safe,
                          site_builder.select(attribute_name,
                                              options_for_select(data[:choices], data[:default]), {},
                                              class: 'governor', data: {governs: attribute_name})
                      ] if data[:type] == :select
    content_tag( :div,
                 label,
                 class: 'label-enclosure',
                 style: "margin-top:.5em") +
        case data[:type]
        when :text
          site_builder.text_field attribute_name
        end
  end
end
