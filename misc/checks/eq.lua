meta1 = {__eq = function(self, other) print('meta1') return rawequal(self, other) end}
meta2 = {__eq = function(self, other) print('meta2') return rawequal(self, other) end}

t1 = setmetatable({}, meta1)
t2 = setmetatable({}, meta2)
t3 = setmetatable({}, meta1)
t4 = {}

print('t1 == nil', t1 == nil)
print('t1 == false', t1 == false)
print('t1 == 1', t1 == 1)
print('t1 == \'1\'', t1 == '1')
print('t1 == print', t1 == print)
print('t1 == t1', t1 == t1)
print('t1 == t2', t1 == t2)
print('t2 == t1', t2 == t1)
print('t1 == t3', t1 == t3)
print('t1 == t4', t1 == t4)
print('t4 == t1', t4 == t1)
