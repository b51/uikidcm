local vector = require('vector')

local a = vector.new({1, 2, 3, 4});
print(a);
local b = vector.ones(4);
print(b);
local c = vector.zeros(4);
print(c);
d = a * 10;
print(d);
e = d / 10;
print(vector.norm(e));
f = vector.slice(d, 2, 3)
print(f)
