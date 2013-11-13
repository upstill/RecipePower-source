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

  def present_table display_table, name, &block

    banner = content_tag :h3, name+" Sorted By "+display_table.sort_field[:name]

    chooser =
        display_table.fields.collect { |field|
          content_tag :li, link_to(field[:name], "/admin/stats?sort_by="+field[:sym].to_s)
        }.join("\n").html_safe

    header =
        display_table.fields.collect { |field|
          content_tag :th, field[:name]
        }.join("\n").html_safe

    body =
        display_table.rows.collect { |row|
          content_tag :tr, display_table.fields.collect { |field|
            field_sym = field[:sym]
            row_matter = yield( row, field_sym ) || row[field_sym]
            row_text = row_matter.class == Float ? format("%.2f", row_matter) : row_matter.to_s
            content_tag :td, row_text.html_safe
          }.join("\n").html_safe
        }.join("\n").html_safe

    %Q{
    #{banner}
      <div class="btn-group">
        <button type="button" class="btn btn-default dropdown-toggle" data-toggle="dropdown">
          Sort By <span class="caret"></span>
        </button>
        <ul class="dropdown-menu" role="menu">#{chooser}</ul>
      </div>
      <table class="table table-striped">
        <thead>
          <tr>#{header}</tr>
        </thead>
        <tbody>#{body}</tbody>
      </table
    }.html_safe

  end

  end