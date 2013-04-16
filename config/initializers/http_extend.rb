require 'net/http'

class URI::HTTP
  # Return a uri with no hazard from a URL with a bad query, 
  # at the cost of losing the query and fragment
  def self.sans_query(url)
    if sublink = url && url.sub(/\?.*/, "")
      begin
        URI sublink
      rescue Exception => e
        return nil
      end
    end
  end
end
