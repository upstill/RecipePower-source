module TableHelper
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
end