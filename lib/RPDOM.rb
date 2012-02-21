require 'open-uri'

# Class RPDOM supports manipulation of the DOM tree in pursuit
# of parsing.
class RPDOM

@@AllowableSymbols = [ :author, :yield, :instruction, :instructions,
:cholesterol, :protein, :fiber, :sugar, :carbohydrates, :unsaturatedFat,
:saturatedFat, :fat, :calories, :servingSize, :nutrition, :totalTime,
:cookTime, :prepTime, :review, :summary, :published, :recipeType,
:condition, :conditions, :unit, :quantity, :amount, :ingredient,
:ingredients, :photo, :fn, :hrecipe, :name ]

@@NewlineTriggers = [ :p, :br, :li ]

   def self.allowable(name)
   	@@AllowableSymbols.include? name.to_sym
   end

@@dbmode = false

# Turn a Nokogiri document into a minimal HTML stream for parsing
# "Minimal" means that the HTML consists only of <span> nodes with 
# classes pertaining to parsing.
# This is a recursive method
   def self.DOMstrip(noko, level)
      result = ""
      if @@dbmode  # Reporting on contents
          result = "\n" + "  " * level + noko.class.to_s + ": "
          if noko.public_methods.include? :attributes
	     attribs = noko.attributes
	     strs = [noko.name, (attribs.length > 0) ? 
	        attribs.values.map {|attr| attr.name+"=\""+attr.value+"\"" }:[]]
	     elmt = strs.flatten.join(' ')
          else
	     elmt = noko.name 
	  end
	  result += "<" + elmt + ">\n"
      end
      result += "\n" if @@NewlineTriggers.include? noko.name.to_sym
      if noko.public_methods.include? :attributes
	 attribs = noko.attributes
	 # We only care if the element has a careworthy class
	 attrib = attribs["class"]
	 unless attrib.blank?
	    classes = 
	      attrib.value.split('\w').keep_if{|str| self.allowable str.to_sym }
	    unless classes.blank?
	       newclasses = classes.join ' ' 
	       return result + 
		   "<span class=\"#{newclasses}\">" +
		   noko.children.map{|child| self.DOMstrip child,level+1}.join +
      		   "</span>"
	       #otherwise, ignore the element
	    end
	 end
      end
      if noko.name.to_sym == :text
         result += noko.to_s
      end
      result += noko.children.map { |child| self.DOMstrip(child, level+1) }.join
   end
end
