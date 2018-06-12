module TableHelper
  def table_collection_selector
    'tbody.collection_list'
  end

  def table_out(list, headers, &block)
    hdrlist = headers.collect { |ttl| "<th>#{ttl}</th>" unless ttl.blank? }.compact.join("\n")
    bodylist = list.collect { |object| "<tr>"+block.call(object)+"</tr>" }.join("\n")
    %Q{<table class="table table-striped">
        <thead>
          <tr>#{hdrlist}</tr>
        </thead>
        <tbody class="collection_list">
  		    #{bodylist}
        </tbody>
        </table>}.html_safe
  end

  def present_table display_table, type = nil, &block

    if type
      chooser =
          display_table.fields.collect { |field|
            content_tag :li, link_to(field[:name], "/admin/data?type=#{type}&sort_by="+field[:sym].to_s)
          }.join("\n").html_safe
      chooser = %Q{
        <div class="btn-group">
          <button type="button" class="btn btn-default dropdown-toggle" data-toggle="dropdown">
              Sort By <span class="caret"></span>
              </button>
          <ul class="dropdown-menu" role="menu">#{chooser}</ul>
        </div>
      }
    end

    banner = content_tag :h3, display_table.name+(chooser ? " Sorted By "+display_table.sort_field[:name] : "")

    header =
        display_table.fields.collect { |field|
          content_tag :th, field[:name]
        }.join("\n").html_safe

    body =
        display_table.rows.collect { |row|
          content_tag :tr, display_table.fields.collect { |field|
                           field_sym = field[:sym]
                           row_matter = yield(row, field_sym) || row[field_sym]
                           row_text = row_matter.class == Float ? format("%.2f", row_matter) : row_matter.to_s
                           content_tag :td, row_text.html_safe
                         }.join("\n").html_safe
        }.join("\n").html_safe

    %Q{
    #{banner}
    #{chooser}
      <table class="table table-striped">
        <thead>
          <tr>#{header}</tr>
        </thead>
        <tbody>#{body}</tbody>
      </table
    }.html_safe

  end

  def format_table_summary strlist, label, options={}
    separator = summary_separator options[:separator]
    inward_separator = summary_separator separator
    strlist.unshift label.html_safe if label.present?
    safe_join strlist, inward_separator
  end

  def format_table_tree strtree, indent=''.html_safe
    if strtree
      return indent + strtree if strtree.is_a?(String)
      safe_join strtree.collect { |item|
        case item
          when String
            (indent + item) if item.present?
          when Array
            format_table_tree item, '&nbsp;&nbsp;&nbsp;&nbsp;'.html_safe + indent
        end
      }.compact, '<br>'.html_safe
    end
  end

end
