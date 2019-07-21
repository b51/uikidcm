local _NAME = "bodyChase";
local Body = require('Body')
local wcm = require('wcm')
local vector = require('vector')
local Config = require('Config')
local behavior = require('behavior')
local walk = require('walk')

local t0 = 0;
local timeout = Config.fsm.bodyChase.timeout;
local maxStep = Config.fsm.bodyChase.maxStep;
local rClose = Config.fsm.bodyChase.rClose;
local tLost = Config.fsm.bodyChase.tLost;
local rFar = Config.fsm.bodyChase.rFar;
local rFarX = Config.fsm.bodyChase.rFarX;

local entry = function()
  print("BodyFSM: ".._NAME.." entry");
  t0 = Body.get_time();
end

local update = function()
  local t = Body.get_time();

  -- get ball position
  local ball = wcm.get_ball();
  local pose = wcm.get_pose();
  local ballR = math.sqrt(ball.x^2 + ball.y^2);
  local goal_defend=wcm.get_goal_defend();

  local ballxy=vector.new( {ball.x,ball.y,0} );
  local posexya=vector.new( {pose.x, pose.y, pose.a} );
  local ballGlobal=util.pose_global(ballxy,posexya);

  local ballR_defend = math.sqrt((ballGlobal[1]-goal_defend[1])^2+
	                               (ballGlobal[2]-goal_defend[2])^2);
  local ballX_defend = math.abs(ballGlobal[1]-goal_defend[1]);

  -- calculate walk velocity based on ball position
  local vStep = vector.new({0,0,0});
  vStep[1] = .6*ball.x;
  vStep[2] = .75*ball.y;
  local scale = math.min(maxStep/math.sqrt(vStep[1]^2+vStep[2]^2), 1);
  vStep = scale*vStep;

  local ballA = math.atan2(ball.y, ball.x+0.10);
  vStep[3] = 0.75*ballA;
  walk.set_velocity(vStep[1],vStep[2],vStep[3]);

  if ballR_defend>rFar and ballX_defend>rFarX and gcm.get_team_role()==0 then
    print("Chase:ballRX", ballR_defend, ballX_defend);
    --ballFar check - Only for goalie
    return "ballFar";
  end

  if (t - ball.t > tLost) then
    return "ballLost";
  end
  if (t - t0 > timeout) then
    return "timeout";
  end
  if (ballR < rClose) then
    behavior.update();
    return "ballClose";
  end
  if (t - t0 > 1.0 and Body.get_sensor_button()[1] > 0) then
    return "button";
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
