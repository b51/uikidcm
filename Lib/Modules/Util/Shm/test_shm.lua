package.cpath = './build/?.so;' .. package.cpath;
local shm = require('shm');

t = shm.new('motion');
t.set(t, "a", 3.14);
print(t.get(t, "a"));

t.set(t, "b", {1, -2, -3})
for k, v in ipairs(t.get(t, "b")) do
  print(k, v)
end

t = shm.new('test', 320000)
t:set('big_img', 153600 )
print(t:get('big_img'))
