local _NAME = "bodyIdle";

local Body = require('Body')
local Motion = require('Motion')

local t0 = 0;

local entry = function()
  print("BodyFSM: ".._NAME.." entry");
  t0 = Body.get_time();
  Motion.event("sit");
end

local update = function()
  Motion.event("sit");
  local t = Body.get_time();
end

local exit = function()
  Motion.sm:set_state('stance');
end

return {
  _NAME = _NAME,
  entry = entry,
  update = update,
  exit = exit,
};
