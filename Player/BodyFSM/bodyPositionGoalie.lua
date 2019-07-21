local _NAME = "bodyPositionGoalie";
local Body = require('Body')
local wcm = require('wcm')
local gcm = require('gcm')
local vector = require('vector')
local util = require('util')
local Config = require('Config')
local walk = require('walk')
local position = require('position')

local t0 = 0;
local direction = 1;

--[[
maxStep = Config.fsm.bodyChase.maxStep;
tLost = Config.fsm.bodyChase.tLost;
timeout = Config.fsm.bodyChase.timeout;
rClose = Config.fsm.bodyChase.rClose;
--]]

local timeout = 20.0;
local maxStep = 0.06;
local maxPosition = 0.55;
local tLost = 6.0;

local rClose = Config.fsm.bodyAnticipate.rClose;
local rCloseX = Config.fsm.bodyAnticipate.rCloseX;
local thClose = Config.fsm.bodyGoaliePosition.thClose;
local goalie_type = Config.fsm.goalie_type;

local entry = function()
  print("BodyFSM: ".._NAME.." entry");
  t0 = Body.get_time();
  if goalie_type>2 then
    HeadFSM.sm:set_state('headSweep');
  else
--    HeadFSM.sm:set_state('headTrack');
  end
end

local update = function()
  local role = gcm.get_team_role();
  if role~=0 then
    return "player";
  end

  local t = Body.get_time();

  local ball = wcm.get_ball();
  local pose = wcm.get_pose();
  local ballGlobal = util.pose_global({ball.x, ball.y, 0}, {pose.x, pose.y, pose.a});
  local tBall = Body.get_time() - ball.t;

  local goal_defend=wcm.get_goal_defend();
  local ballxy=vector.new( {ball.x,ball.y,0} );
  local posexya=vector.new( {pose.x, pose.y, pose.a} );
  local ballGlobal=util.pose_global(ballxy,posexya);
  local ballR_defend = math.sqrt(
	    (ballGlobal[1]-goal_defend[1])^2+
	        (ballGlobal[2]-goal_defend[2])^2);
  local ballX_defend = math.abs(ballGlobal[1]-goal_defend[1]);

  --------------------------tse---------------------------
  local aBall = math.atan2(ball.y,ball.x);
  --print("PositionGoalie: aBall",aBall*180/math.pi);

  if aBall > 60*math.pi/180 then
     print("PositionGoalie: Turning Left");
     direction = 1;
  elseif aBall < -60*math.pi/180 then
     print("PositionGoalie: Turning Right");
     direction = -1;
  elseif aBall > -15*math.pi/180 and
         aBall < 15*math.pi/180 then
     direction = 0;
  end

  walk.set_velocity(0, 0, direction*0.3);

  if direction == 0 then
     return "done";
  end
end

local exit = function()
  if goalie_type>2 then
    HeadFSM.sm:set_state('headTrack');
  end
end

return {
  _NAME = _NAME,
  entry = entry,
  update = update,
  exit = exit,
};
