require './lib/Domain.rb'

class LinkRef < ActiveRecord::Base
    belongs_to :link
    belongs_to :tag
    # before_save :ensure_unique
    
    # def ensure_unique
    # puts "Ensuring uniqueness of user #{self.user_id.to_s} to recipe #{self.recipe_id.to_s}"
    # end
    
    # Associate a link with a tag in the database. Parameters:
    #  :uri
    #  :type => :vendor, :store, :book, :blog, :site, :video, :glossary
    #  :tag => if string, the tag's string (typed acc'ng to :keytype)
    #          if integer, the tag's integer key
    #   :tagtype => integer or symbol for the tag's type (iff :tag is string)
    # NB: URI and :key are both required
    def self.associate (*params)
        paramhash = params.first
        # Find or create a matching link entry
        uri = paramhash[:uri]
        if paramhash[:resource_type]
            # Should be throwing an error if resource_type doesn't make sense
            resource_type = Link.resource_type_inDB paramhash[:resource_type]
            # Asserted type => type existing record if nil
            unless link = Link.find_by_uri_and_resource_type(uri, resource_type)
                link = Link.find_or_create_by_uri_and_resource_type(uri, nil)
                link.resource_type = resource_type
                link.save
            end
        else
            # No asserted type => Use existing record, if any
            link = Link.find_or_create_by_uri(uri)
        end
        # Get domain and path from url
        link.save if link.domain.nil? && (link.domain = domain_from_url(uri))
        
        # Find or create a matching key entry
        Tag.strmatch paramhash[:tag], paramhash[:userid], paramhash[:tagtype], true
        
        # We have a link and at least one tag. Join the link to all tags which
        # match the tag name, modulo parametrization
        Tag.strmatch(paramhash[:tag], nil, paramhash[:tagtype], false).each do |tag|
            LinkRef.find_or_create_by_link_id_and_tag_id(link.id, tag.id) 
        end
        [link, link.tags]
    end
    
    # Import a file of tag/link pairs
    # -- pairs are separated by \t
    # -- the tag may be multiple tags, separated by ';'
    def self.import_file(fname)
        superid = User.super_id
        File.open(fname).each do |line|
            fields = line.chomp.split "\t"
            uri = fields[1]
            tagtype = fields[2]
            fields.first.split('; ').each do |tag|
                tagtype.split('; ').each do |type|
                    puts self.associate :tag=>tag, :resource_type=>:glossary, :uri=>uri, :tagtype=>type, :userid=>superid
                end
            end
        end
    end
end
