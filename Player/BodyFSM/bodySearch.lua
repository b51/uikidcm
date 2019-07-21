local _NAME = "bodySearch";
local Body = require('Body')
local wcm = require('wcm')
local mcm = require('mcm')
local vector = require('vector')
local Config = require('Config')
local walk = require('walk')

local t0 = 0;
local direction = 1;
local vSpin = Config.fsm.bodySearch.vSpin or 0.3;
local ball = {};
local role = 0;
local timeout = Config.fsm.bodySearch.timeout or 3.5 * Config.speedFactor;

local entry = function()
  print("BodyFSM: ".._NAME.." entry");

  t0 = Body.get_time();

  -- set turn direction to last known ball position
  ball = wcm.get_ball();
  if (ball.y > 0) then
    direction = 1;
    mcm.set_walk_isSearching(1);
  else
    direction = -1;
    mcm.set_walk_isSearching(-1);
  end

  role = gcm.get_team_role();
  --Force attacker for demo code
  if Config.fsm.playMode==1 then
    role=1;
  end
  if role==1 then
    timeout = Config.fsm.bodySearch.timeout or 10.0*Config.speedFactor;
  end
end

local update = function()
  local t = Body.get_time();
  ball = wcm.get_ball();

  -- search/spin until the ball is found
  walk.set_velocity(0, 0, direction*vSpin);

  if (t - ball.t < 0.2) then
    --print("Search: ballFound");
    if role==0 then
      return "ballgoalie";
    else
      return "ball";
    end
  end
  if (t - t0 > timeout) then
    if role==0 then
      return "timeoutgoalie"
    else
      return "timeout";
    end
  end
end

local exit = function()
  mcm.set_walk_isSearching(0);
end

return {
  _NAME = _NAME,
  entry = entry,
  update = update,
  exit = exit,
};
