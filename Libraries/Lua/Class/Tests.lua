dofile('./Class.lua')


function test_class()
    local Animal = {
        name = Field(),
        public_name = Field(true),
        
    }
    function Animal:new(name)
        local values = valuesof(self)
        values.name = name
        self.public_name = name
    end
    
    function Animal:print()
        print('Animal name is', self.name, ', public name is', self.public_name)
    end

    Animal = Class('Animal', Animal)
    
    local animal = Animal:new('Pet')
    animal:print()
    animal.public_name = 'Peter'
    animal:print()
end

do
    local orig_print = print
    function print(...)
        local args = table.pack(...)
        for i = 1, args.n do
            args[i] = tostring(args[i])
        end
        orig_print(table.concat(args, ' '))
    end


    Class = InitClasses()
    typeof = Class.typeof
    valuesof = Class.valuesof
    nameof = Class.nameof
    subclassesof = Class.subclassesof
    
    issubclass = Class.issubclass
    isinstance = Class.isinstance
    
    super = Class.super

    Field = Class.field
    Property = Class.property
    Meta = Class.meta
    
    test_class()
end