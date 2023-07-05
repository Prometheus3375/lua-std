function InitAbstractCollections()
    local abc = {}

    local function iterator_iter(self)
        return self
    end

    function abc.Iterator(name, deftable, parent)
        if common.isNil(deftable.__iter) then
            deftable.__iter = iterator_iter
        end
        
        return Class(name, deftable, parent)
    end
    
    return abc
end
