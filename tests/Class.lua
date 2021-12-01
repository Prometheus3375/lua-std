dofile('Library/Class.lua')

function test_class()
  local Animal = {
    name = Field(),
    public_name = Field(true),
  }

  function Animal:new(name)
    local values = self.__values
    values.name = name
    self.public_name = name
  end

  function Animal:print()
    print('Animal name is ' .. self.name .. ', public name is ' .. self.public_name)
  end

  Animal = Class('Animal', Animal)

  local animal = Animal:new('Pet')
  animal:print()
  animal.public_name = 'Peter'
  animal:print()
end

function test_inheritance()
  local Animal = {
    name = Field(),
  }

  function Animal:new(name)
    local values = self.__values
    values.name = name
  end

  function Animal:print()
    print('Animal name is ' .. self.name)
  end

  function Animal:feed()
    print('Animal ' .. self.name .. ' feeds')
  end

  Animal = Class('Animal', Animal)

  local Mammal = {
    children = Field(),
  }

  function Mammal:feed()
    super(self):feed()
    print('Mammal ' .. self.name .. ' feeds its children')
  end

  Mammal = Animal:subclass('Mammal', Mammal)
  print('Superclass of ' .. nameof(Mammal) .. ' is ' .. nameof(Mammal.super))

  local mammal = Mammal:new('Peter')
  mammal:print()
  mammal:feed()
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
  nameof = Class.nameof

  issubclass = Class.issubclass
  isinstance = Class.isinstance

  super = Class.super

  Field = Class.field
  Property = Class.property
  Meta = Class.meta

  test_class()
  test_inheritance()
end
