local _NAME = "bodyObstacleAvoid";
local Body = require('Body')
local wcm require('wcm')
local gcm require('gcm')
local vector = require('vector')
local walk = require('walk')
-- local UltraSound = require('UltraSound')

local t0 = 0;
local timeout = 5.0;
local direction = 1;
-- TODO(b51): This module used ultrasound, but we got none,
--            need use other methods to detect obstacles

local entry = function()
  print("BodyFSM: ".._NAME.." entry");
  t0 = Body.get_time();
  -- us = UltraSound.check_obstacle();
  direction = 1;
  -- if us[1] > us[2] then
  --   direction = -1;
  -- end
end

local update = function()
  local t = Body.get_time();
  walk.set_velocity(0, direction*0.04, 0);

  -- us = UltraSound.check_obstacle();
  -- if (us[1] < 7 and us[2] < 7) then
  return 'clear';
  -- end

  -- if (t - t0 > timeout) then
    -- return "timeout";
  --end
end

local exit = function()
  walk.start();
end

return {
  _NAME = _NAME,
  entry = entry,
  update = update,
  exit = exit,
}
