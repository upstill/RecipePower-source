class TypeMap < Array
    
    def initialize init_table, nullname
        @TypeToSym = [ nil ]
        @TypeToName = [ nullname ]
        @SymToType = { nil => 0 }
        @NameToType = { nil => 0, "" => 0 }
        @List = []
        init_table.each { |entry| 
            sym = entry.first; name = entry.last.first; typenum = entry.last.last
            @TypeToSym[typenum] = sym
            @TypeToName[typenum] = name
            @List += entry.last
            @SymToType[sym] = typenum
            @NameToType[name.gsub(/\s/, '')] = typenum
        }
    end
    
    def num(tt)
        if tt.kind_of? Fixnum 
            @TypeToSym[tt] ? tt : 0
        elsif (tt.kind_of? Symbol)
            @SymToType[tt] || 0
        elsif(tt.kind_of? String)
            @NameToType[tt.gsub(/\s/, '')] || 0
        elsif tt.kind_of? Array
            tt.first && tt.collect { |type| num type }
        elsif !tt
            0
        end
    end
    
    def name tt
        @TypeToName[num(tt)]
    end
    
    def stripped_name tt
        @TypeToName[num(tt)].gsub(/\s/, '')
    end
    
    def sym tt
        @TypeToSym[num(tt)]
    end
    
    # Return a list of name/value pairs, suitable for building a select list
    def list
        @List
    end
end
