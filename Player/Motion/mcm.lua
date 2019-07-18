local shm = require('shm');
local util = require('util');
local vector = require('vector');
local Body = require('Body')--123456
local Config = require('Config');

local mcm = {};
-- shared properties
local shared = {};
local shsize = {};

shared.walk = {};
shared.walk.bodyOffset = vector.zeros(3);
shared.walk.tStep = vector.zeros(1);
shared.walk.bodyHeight = vector.zeros(1);
shared.walk.stepHeight = vector.zeros(1);
shared.walk.footY = vector.zeros(1);
shared.walk.supportX = vector.zeros(1);
shared.walk.supportY = vector.zeros(1);
shared.walk.uLeft = vector.zeros(3);
shared.walk.uRight = vector.zeros(3);

--Robot specific calibration values
shared.walk.footXComp = vector.zeros(1);
shared.walk.kickXComp = vector.zeros(1);
shared.walk.headPitchBiasComp = vector.zeros(1);


-- How long have we been still for?
shared.walk.stillTime = vector.zeros(1);

-- Is the robot moving?
shared.walk.isMoving = vector.zeros(1);

--If the robot carries a ball, don't move arms
shared.walk.isCarrying = vector.zeros(1);
shared.walk.bodyCarryOffset = vector.zeros(3);

--To notify world to reset heading
shared.walk.isFallDown = vector.zeros(1);

--Is the robot spinning in bodySearch?
shared.walk.isSearching = vector.zeros(1);

shared.motion = {};
--Should we perform fall check
shared.motion.fall_check = vector.zeros(1);

local _ENV = {print = print};
util.init_shm_segment(_ENV, "mcm", shared, shsize);
mcm = _ENV;

-- helper functions
mcm.get_odometry = function(u0)
--[[  if (not u0) then--123456路程计改变
    u0 = vector.new({0, 0, 0});
  end
  local uFoot = util.se2_interpolate(.5, get_walk_uLeft(), get_walk_uRight()); --123456
  return util.pose_relative(uFoot, u0), uFoot;]]--
  if (not u0) then
    u0 = vector.new({0, 0, 0});
  end
  local uFoot = Body.get_sensor_odometry();
  return util.pose_relative(uFoot, u0), uFoot;
end

--Now those parameters are dynamically adjustable
local footX = Config.walk.footX or 0;
local kickX = Config.walk.kickX or 0;
local footXComp = Config.walk.footXComp or 0;
local kickXComp = Config.walk.kickXComp or 0;
local headPitchBias= Config.walk.headPitchBias or 0;
local headPitchBiasComp= Config.walk.headPitchBiasComp or 0;

set_walk_footXComp(footXComp);
set_walk_kickXComp(kickXComp);
set_walk_headPitchBiasComp(headPitchBiasComp);

mcm.get_footX = function()
  return get_walk_footXComp() + footX;
end

mcm.get_kickX = function()
  return get_walk_kickXComp();
end

mcm.get_headPitchBias = function()
  return get_walk_headPitchBiasComp()+headPitchBias;
end

return mcm;
