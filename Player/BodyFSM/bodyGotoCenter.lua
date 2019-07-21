local _NAME = "bodyGotoCenter";
local Body  = require('Body')
local wcm = require('wcm')
local gcm = require('gcm')
local vector = require('vector')
local Config = require('Config')
local walk = require('walk')

local t0 = 0;

local maxStep = Config.fsm.bodyGotoCenter.maxStep;
local rClose = Config.fsm.bodyGotoCenter.rClose;
local timeout = Config.fsm.bodyGotoCenter.timeout;
--TODO: Goalie handling, velocity limit

local entry = function()
  print("BodyFSM: ".._NAME.." entry");
  t0 = Body.get_time();
end

local update = function()
  local t = Body.get_time();

  local ball = wcm.get_ball();
  local pose = wcm.get_pose();
  local tBall = Body.get_time() - ball.t;

  local id = gcm.get_team_player_id();
  local role = gcm.get_team_role();
  local centerPosition;
  if id == 1 then
    -- goalie
    centerPosition = vector.new(wcm.get_goal_defend());
    centerPosition[1] = centerPosition[1] - util.sign(centerPosition[1]) * .5;
    -- face center
    centerPosition[3] = math.atan2(centerPosition[2], 0 - centerPosition[1]);

    -- use stricter thresholds
    rClose = .1;
  else
    if (role == 2) then
      -- defend
      centerPosition = vector.new(wcm.get_goal_defend())/2.0;
    elseif (role == 3) then
      -- support
      centerPosition = vector.zeros(3);
    else
      -- attack
      centerPosition = vector.new(wcm.get_goal_attack())/2.0;
    end
  end

  local centerRelative = util.pose_relative(centerPosition,
                                            {pose.x, pose.y, pose.a});
  local rCenterRelative = math.sqrt(centerRelative[1]^2 +
                                    centerRelative[2]^2);

  local vx = maxStep * centerRelative[1]/rCenterRelative;
  local vy = maxStep * centerRelative[2]/rCenterRelative;
  local va;
  if id == 1 then
    va = .2 * centerRelative[3];
  else
    va = .2 * math.atan2(centerRelative[2], centerRelative[1]);
  end
  walk.set_velocity(vx, vy, va);

  if (tBall < 1.0) then
    return 'ballFound';
  end
  if ((t - t0 > 5.0) and (rCenterRelative < rClose)) then
    return 'done';
  end
  if (t - t0 > timeout) then
    return "timeout";
  end
end

local exit = function()
end

return {
  _NAME = _NAME,
  entry = entry,
  update = update,
  exit = exit,
}
