local Body = require('Body')
local Motion = require('Motion')

local t0 = 0;

local entry = function()
  print("BodyFSM: bodyIdle entry");
  t0 = Body.get_time();
  Motion.event("sit");
end

local update = function()
  Motion.event("sit");
  t = Body.get_time();
end

local exit = function()
  Motion.sm:set_state('stance');
end

return {
  _NAME = "bodyIdle",
  entry = entry,
  update = update,
  exit = exit,
}
