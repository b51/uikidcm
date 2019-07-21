local _NAME = "bodyObstacle";
local Body = require('Body')
local wcm = require('wcm')
local gcm = require('gcm')
local vector = require('vector')
local walk = require('walk')

local t0 = 0;
local timeout = 3.0;

local entry = function()
  print("BodyFSM: ".._NAME.." entry");
  t0 = Body.get_time();
  walk.set_velocity(0,0,0);
  walk.stop();
end

local update = function()
  local t = Body.get_time();
  walk.stop();
  --us = UltraSound.checkObstacle();
  -- if ((t - t0 > 1.0) and (us[1] < 7 and us[2] < 7)) then
  if (t - t0 > 1.0) then
    print('Exiting Obstacle: clear');
    return 'clear';
  end

  if (t - t0 > timeout) then
    print('Exiting Obstacle: timeout');
    return "timeout";
  end
end

local exit = function()
  walk.start();
end

return {
  _NAME = _NAME,
  entry = entry,
  update = update,
  exit = exit,
};
