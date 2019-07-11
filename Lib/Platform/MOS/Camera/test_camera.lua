package.cpath = './build/?.so;' .. package.cpath
local Camera = require("V4LCam")

width = 1280;
height = 720;
Camera.init(width, height);
print(Camera.get_width());
print(Camera.get_height());
while true do
  jpeg  = Camera.get_image();
  print(jpeg.size)
  print(jpeg.data)
end
