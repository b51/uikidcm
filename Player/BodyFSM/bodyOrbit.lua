local _NAME = "bodyOrbit";
local Body = require('Body')
local wcm = require('wcm')
local walk = require('walk')
local vector = require('vector')
local Config = require('Config')
local behavior = require('behavior')

local t0 = 0;
local timeout = Config.fsm.bodyOrbit.timeout;
local maxStep = Config.fsm.bodyOrbit.maxStep;
local rOrbit = Config.fsm.bodyOrbit.rOrbit;
local rFar = Config.fsm.bodyOrbit.rFar;
local thAlign = Config.fsm.bodyOrbit.thAlign;
local tLost = Config.fsm.bodyOrbit.tLost;
local direction = 1;
local kickAngle = 0;

local get_orbit_direction = function()
  local attackBearing = wcm.get_attack_bearing();
  local angle = util.mod_angle(attackBearing-kickAngle);

  if angle>0 then
    dir = 1;
  else
    dir = -1;
  end
  return dir, angle;
end

local entry = function()
  print("BodyFSM: ".._NAME.." entry");
  t0 = Body.get_time();
  behavior.update();
  kickAngle=  wcm.get_kick_angle();
  direction,angle=get_orbit_direction();
end

local update = function()
  local t = Body.get_time();

  local ball = wcm.get_ball();

  local ballR = math.sqrt(ball.x^2 + ball.y^2);
  local ballA = math.atan2(ball.y, ball.x+0.10);
  local dr = ballR - rOrbit;
  local aStep = ballA - direction*(90*math.pi/180 - dr/0.40);
  local vx = maxStep*math.cos(aStep);

  --Does setting vx to 0 improve performance of orbit?--

  vx = 0;

  local vy = maxStep*math.sin(aStep);
  local va = 0.75*ballA;

  walk.set_velocity(vx, vy, va);

  if (t - ball.t > tLost) then
    return 'ballLost';
  end
  if (t - t0 > timeout) then
    return 'timeout';
  end
  if (ballR > rFar) then
    return 'ballFar';
  end

  local dir, angle = get_orbit_direction();

  if (math.abs(angle) < thAlign) then
    return 'done';
  end

  --Overshoot escape
  if direction~=dir then
    return 'done'
  end

end

local exit = function()
end

return {
  _NAME = _NAME,
  entry = entry,
  update = update,
  exit = exit,
};
