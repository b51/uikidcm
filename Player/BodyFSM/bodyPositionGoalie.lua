module(..., package.seeall);

require('Body')
require('walk')
require('vector')
require('util')
require('Config')
require('wcm')
require('gcm')
require('UltraSound')
require('position')

t0 = 0;
direction = 1;

--[[
maxStep = Config.fsm.bodyChase.maxStep;
tLost = Config.fsm.bodyChase.tLost;
timeout = Config.fsm.bodyChase.timeout;
rClose = Config.fsm.bodyChase.rClose;
--]]

timeout = 20.0;
maxStep = 0.06;
maxPosition = 0.55;
tLost = 6.0;

rClose = Config.fsm.bodyAnticipate.rClose;
rCloseX = Config.fsm.bodyAnticipate.rCloseX;
thClose = Config.fsm.bodyGoaliePosition.thClose;
goalie_type = Config.fsm.goalie_type;

function entry()
  print(_NAME.." entry");
  t0 = Body.get_time();
  if goalie_type>2 then
    HeadFSM.sm:set_state('headSweep');
  else
--    HeadFSM.sm:set_state('headTrack');
  end
end

function update()
  role = gcm.get_team_role();
  if role~=0 then
    return "player";
  end

  local t = Body.get_time();

  ball = wcm.get_ball();
  pose = wcm.get_pose();
  ballGlobal = util.pose_global({ball.x, ball.y, 0}, {pose.x, pose.y, pose.a});
  tBall = Body.get_time() - ball.t;

  goal_defend=wcm.get_goal_defend();
  ballxy=vector.new( {ball.x,ball.y,0} );
  posexya=vector.new( {pose.x, pose.y, pose.a} );
  ballGlobal=util.pose_global(ballxy,posexya);
  ballR_defend = math.sqrt(
	(ballGlobal[1]-goal_defend[1])^2+
	(ballGlobal[2]-goal_defend[2])^2);
  ballX_defend = math.abs(ballGlobal[1]-goal_defend[1]);

  --------------------------tse---------------------------
  aBall = math.atan2(ball.y,ball.x);
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
  -------------------------tse-----------------------------
end

function exit()
  if goalie_type>2 then
    HeadFSM.sm:set_state('headTrack');
  end
end
