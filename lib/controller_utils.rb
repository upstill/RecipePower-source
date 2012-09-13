# Use 'with_format' when a controller needs to render one format for another.
# Canonical use is to render HTML to a string for passing as part of a JSON response.

def with_format(format, &block)
    old_formats = formats
    self.formats = [format]
    result = block.call
    self.formats = old_formats
    result
end

