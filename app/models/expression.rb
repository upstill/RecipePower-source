class ExpressionValidator < ActiveModel::Validator
  def validate(record)
    if (record.tag_id)
      tag = Tag.find record.tag_id
      if record.referent_id
        ref = Referent.find record.referent_id
        if tag.tagtype != ref.typenum && (tag.tagtype > 0)
          record.errors[:tag_id] << "#{tag.name} is a '#{tag.typename}', not '#{ref.typename}'"
        end
      end
    else
      record.errors[record.tag_id ? :referent_id : :tag_id] << "Must have tag id."
    end
  end
end

require 'type_map.rb'

class Expression < ActiveRecord::Base
  attr_accessible :tag_id, :referent_id
  belongs_to :tag
  belongs_to :referent

  before_save :fix_type

  def fix_type
    tg = self.tag
    ref = self.referent
    tg.typenum = ref.typenum if (tg.typenum != ref.typenum) && (tg.typenum == 0)
  end

  attr_accessible :tag, :tag_id, :referent, :referent_id, :locale, :form, :tagname, :tag_token, :localename, :formname

  @@Attribs = [:tag_id, :referent_id, :form, :locale]

  @@Locales = TypeMap.new({
                              en: ["English", 1],
                              it: ["Italian", 2],
                              es: ["Spanish", 3],
                              fr: ["French", 4],
                              ru: ["Russian", 5],
                              de: ["German", 6]
                          }, "No Locale")

  def self.localenum tt
    @@Locales.num tt
  end

  def self.localesym tt
    @@Locales.sym tt
  end

  def self.localename tt
    @@Locales.name tt
  end

  def localesym
    @@Locales.sym self.locale
  end

  def localename
    @@Locales.name self.locale
  end

  def localename=(tt)
    self.set_locale tt
  end

  def set_locale tt
    self.locale = @@Locales.sym(tt)
  end

  def self.locales
    @@Locales.list
  end

  # Access/manipulation of 'form' attribute. Stored in database as an int,
  # Read and written by ints, symbols and strings

  @@Forms = TypeMap.new({
                            generic: ["Generic", 1],
                            singular: ["Singular", 2],
                            plural: ["Plural", 3]
                        }, "Unknown Form")

  # Set the form by reference to any of the accepted datatypes
  def set_form tt
    self.form = @@Forms.num(tt)
  end

  # Get the type number, taking any of the accepted datatypes
  def self.formnum tt
    @@Forms.num tt
  end

  # Get the symbol for the type, taking any of the accepted datatypes
  def self.formsym tt
    @@Forms.sym tt
  end

  # Get the name for the type, taking any of the accepted datatypes
  def self.formname tt
    @@Forms.name tt
  end

  # Return the symbol for the type of self
  def formsym
    @@Forms.sym self.form
  end

  # Return the name for the type of self
  def formname
    @@Forms.name self.form
  end

  def formname=(f)
    self.set_form f
  end

  def set_form tt
    self.form = @@Forms.num(tt)
  end

  # Return a list of name/type pairs, suitable for making a selection list
  def self.forms
    @@Forms.list
  end

  validates_with ExpressionValidator

  # Clean up a hash of arguments for a search by
  # 1) removing any with nil values
  # 2) making any type specifiers conform to the type in the database
  # 3) ignoring those which aren't Expression attributes
  def self.scrub_args(args)
    newargs = {}
    args.keys.each do |k|
      k = k.to_sym
      val = args[k]
      if val && @@Attribs.include?(k.to_sym)
        case k
          when :form
            val = self.formnum val
          when :locale
            val = self.localesym(val).to_s
        end
        newargs[k] = val
      end
    end
    newargs
  end

  # Make a new expression according to the arguments, trying first to find a
  # match. The trick is that when either the locale or the form aren't specified,
  # we'll match any expression on the referent and id.
  def self.find_or_create refid, tagid, args = {}
    # Collect the relevant arguments into the whereargs hash
    whereargs = self.scrub_args args
    whereargs[:referent_id] = refid
    whereargs[:tag_id] = tagid
    self.where(whereargs).first || self.create(whereargs)
  end

  def tagname
    self.tag ? self.tag.name : "**no tag**"
  end

  # Tag_token: a virtual attribute for taking tag specifications from tokenInput.
  # These will either be a tag key (integer) or a token string. Integers are easy;
  # If a token string, it has a type specifier for the tag prepended.
  # Before accepting a tag name as a new tag, we do our due diligence to find the
  # proferred string among 1) tags of the specified type, and 2) free (untyped) tags.
  def tag_token()
    self.tag ? self.tag.id.to_s : ""
  end

  def tag_token=(t)
    if (id = t.to_i) > 0
      self.tag_id = id
    else
      t.sub!(/^\'(.*)\'$/, '\1') # Strip out the single quotes
      params = t.split(/::/)
      tagtype = params.first.to_i
      tagname = params.last
      # Try to match all within the type
      tag = Tag.strmatch(tagname, tagtype: tagtype, matchall: true).first ||
          Tag.strmatch(tagname, assert: true).first # Try to pick up a match from the free tags
      self.tag_id = tag.id
    end
    self.tag_id
  end

  def self.qa
    bad_exprs = []
    Expression.includes(:tag).all.find_in_batches do |group|
      group.each { |expr|
        if expr.tag == nil
          puts "Nil tag for Expression ##{expr.id} to tag ##{expr.tag_id}"
          bad_exprs << expr
        end
      }
    end
    bad_exprs.each { |expr|
      if (ref = expr.referent) && (ref.tag_id == expr.tag_id)
        # Referent has this same bogus tag => replace it with another, if possible
        ref.tag_id = nil
        (ref.expressions.to_a - [expr]).each { |altexpr|
          if altexpr && altexpr.tag_id
            ref.tag_id = altexpr.tag_id
            break
          end
        }
      end
    }
  end
end
