local Body = require('Body')
local fsm = require('fsm')
local mcm = require('mcm')
local gcm = require('gcm')
local vector = require('vector')
local Config = require('Config')

-- Motion FSMs
local relax = require('relax')
local stance = require('stance')
local nullstate = require('nullstate')
local walk = require('walk')
local sit = require('sit')
local standstill = require('standstill') -- This makes torso straight (for webots robostadium)
local falling = require('falling')
local standup = require('standup')
local kick = require('kick')
local align = require('align') -- slow, non-dynamic stepping for fine alignment before kick
--For diving
local divewait = require('divewait')
local dive = require('dive')
-- Aux
local grip = require('grip')

-- TODO(b51): Motion FSM needs to be recontructed.
--            Some variable I change to local may cause the Motion
--            fsm this variable belongs to cannot exit loop

local fallAngle = Config.fallAngle or 30*math.pi/180;
local sm = {};
sm = fsm.new(relax);
sm:add_state(stance);
sm:add_state(nullstate);
sm:add_state(walk);
sm:add_state(sit);
sm:add_state(standup);
sm:add_state(falling);
sm:add_state(kick);
sm:add_state(standstill);
sm:add_state(grip);
sm:add_state(divewait);
sm:add_state(dive);
sm:add_state(align);--初始化各状态机名称

sm:set_transition(sit, 'done', relax);
sm:set_transition(sit, 'standup', stance);
sm:set_transition(relax, 'standup', stance);
sm:set_transition(relax, 'diveready', divewait);

sm:set_transition(stance, 'done', walk);
sm:set_transition(stance, 'sit', sit);
sm:set_transition(stance, 'diveready', divewait);

sm:set_transition(walk, 'sit', sit);
sm:set_transition(walk, 'stance', stance);
sm:set_transition(walk, 'standstill', standstill);
sm:set_transition(walk, 'pickup', grip);
sm:set_transition(walk, 'throw', grip);
sm:set_transition(walk, 'align', align);--猜测，transition状态转换，当满足中间字符串信息传入时，由前一状态跳转至后一状态。

--align transitions
sm:set_transition(align, 'done', walk);

--dive transitions
sm:set_transition(walk, 'diveready', divewait);
sm:set_transition(walk, 'dive', dive);

sm:set_transition(divewait, 'dive', dive);
sm:set_transition(divewait, 'walk', stance);
sm:set_transition(divewait, 'standup', stance);
sm:set_transition(divewait, 'sit', sit);

sm:set_transition(dive, 'done', stance);
sm:set_transition(dive, 'divedone', falling);

--standstill makes the robot stand still with 0 bodytilt (for webots)
sm:set_transition(standstill, 'stance', stance);
sm:set_transition(standstill, 'walk', stance);
sm:set_transition(standstill, 'sit', sit);
sm:set_transition(standstill, 'diveready', divewait);

-- Grip
sm:set_transition(grip, 'timeout', grip);
sm:set_transition(grip, 'done', stance);

-- falling behaviours

sm:set_transition(walk, 'fall', falling);
sm:set_transition(align, 'fall', falling);
sm:set_transition(divewait, 'fall', falling);
sm:set_transition(falling, 'done', standup);
sm:set_transition(standup, 'done', stance);
sm:set_transition(standup, 'fail', standup);

-- kick behaviours
sm:set_transition(walk, 'kick', kick);
sm:set_transition(kick, 'done', walk);

-- set state debug handle to shared memory settor
sm:set_state_debug_handle(gcm.set_fsm_motion_state);

-- TODO: fix kick->fall transition
--sm:set_transition(kick, 'fall', falling);

local bodyTilt = Config.walk.bodyTilt or 0;
-- For still time measurement (dodgeball)
local stillTime = 0;
local stillTime0 = 0;
local wasStill = false;

local update_shm = function()
  local util = require('util');
  -- Update the shared memory
  mcm.set_walk_bodyOffset(walk.get_body_offset());
  mcm.set_walk_uLeft(walk.uLeft);
  mcm.set_walk_uRight(walk.uRight);
  mcm.set_walk_stillTime(stillTime);
end

local event = function(e)
  sm:add_event(e);
end

local entry = function()
  Body.set_state_sensorEnable(1);--123456传感器常开
  Body.set_state_torqueEnable(1);--123456舵机使能
  Body.set_state_gaitReset(1);--123456复位
  sm:entry()
  mcm.set_walk_isFallDown(0);
  -- TODO(b51): Add fall down check switch to config
  mcm.set_motion_fall_check(1); --check fall by default
end

local update = function()
  local imuAngle = Body.get_sensor_imuAngle();
  local maxImuAngle = math.max(math.abs(imuAngle[1]), math.abs(imuAngle[2]-bodyTilt));
  local fall = mcm.get_motion_fall_check() --Should we check for fall? 1 = yes
  if (maxImuAngle > fallAngle and fall == 1) then
    print('falling event detected',maxImuAngle);
    sm:add_event("fall");
    mcm.set_walk_isFallDown(1); --Notify world to reset heading
  else
    mcm.set_walk_isFallDown(0);
  end
  -- Keep track of how long we've been still for
  -- Update our last still measurement
  if (walk.still and not wasStill) then
    stillTime0 = Body.get_time();
    stillTime = 0;
  elseif (walk.still and wasStill) then
    stillTime = Body.get_time() - stillTime0;
  else
    stillTime = 0;
  end
  wasStill = walk.still;

  if walk.active or align.active then
    mcm.set_walk_isMoving(1);
  else
    mcm.set_walk_isMoving(0);
  end

  sm:update();
  -- update shm
  update_shm();
end

local exit = function()
  sm:exit();
end

return {
  update_shm = update_shm,
  event = event,
  entry = entry,
  update = update,
  exit = exit,
  sm = sm,
};
