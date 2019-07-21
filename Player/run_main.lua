package.cpath = './Lib/?.so;' .. package.cpath

local unix = require('unix');
local main = require('main');

while 1 do
  tDelay = 0.005*1E6;
  main.update();
  unix.usleep(tDelay);
end
