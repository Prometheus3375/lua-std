t = {[0] = 8, [1] = 5, [2] = 4, [3] = 7, [5] = 7, k = 1, l = 2, }

print(#t)
for i, v in ipairs(t) do
  print(i, v)
end
print()

t.a = 1
t.b = 1
t.c = 4
t.d = 6

print(#t)
for i, v in ipairs(t) do
  print(i, v)
end
print()

meta = {__len = function() return 5 end}
t = setmetatable({1, 2, 3, 4, 5, 6, 7, 8, 9, 0}, meta)
print(#t)
for i, v in ipairs(t) do
  print(i, v)
end
