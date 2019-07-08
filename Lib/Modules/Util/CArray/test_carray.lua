package.cpath = './build/?.so;' .. package.cpath;
local carray = require('carray');

width = 320;
height = 240;

rgb = carray.new('c', 3*width*height);
rgb[100] = 65;
prgb = carray.pointer(rgb);
print(rgb)
print(prgb)
print(rgb[10])
print(rgb[100])

--TODO(b51): Add carray cast test
--[[
pyuyv = ImageProc.rgb_to_yuyv(prgb, width, height);
yuyv = carray.cast(pyuyv, 'i', width*height);

plabel = ImageProc.yuyv_to_label(pyuyv, pcdt, width, height);
label = carray.cast(plabel, 'c', width*height);
--]]
