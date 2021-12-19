dofile('library/common.lua')
dofile('library/Class.lua')

function test_class()
  local Animal = {
    name = Field(),
    public_name = Field(true),
  }

  function Animal:__init(name)
    local values = self.__values
    values.name = name
    self.public_name = name
  end

  function Animal:print()
    print('Animal name is ' .. self.name .. ', public name is ' .. self.public_name)
  end

  Animal = Class('Animal', Animal)

  local animal = Animal('Pet')
  animal:print()
  animal.public_name = 'Peter'
  animal:print()
end

function test_inheritance()
  local Animal = {
    name = Field(),
  }

  function Animal:__init(name)
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

  Mammal = Class('Mammal', Mammal, Animal)
  print('Superclass of ' .. Mammal.__name .. ' is ' .. Mammal.__superclass.__name)

  local mammal = Mammal('Peter')
  mammal:print()
  mammal:feed()
end

do
  common = InitCommonPackage()
  Class = InitClassPackage()

  issubclass = common.issubclass
  isinstance = common.isinstance

  super = Class.super

  Field = Class.field
  Property = Class.property
  Meta = Class.meta

  test_class()
  collectgarbage()
  test_inheritance()
end
