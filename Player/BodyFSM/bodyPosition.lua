local _NAME = "bodyPosition";
local Body = require('Body')
local wcm = require('wcm')
local util = require('util')
local vector = require('vector')
local Config = require('Config')
local Team = require('Team')
local walk = require('walk')

local behavior = require('behavior')
local position = require('position')

local t0 = 0;

local tLost = Config.fsm.bodyPosition.tLost;
local timeout = Config.fsm.bodyPosition.timeout;
local thClose = Config.fsm.bodyPosition.thClose;
local rClose= Config.fsm.bodyPosition.rClose;
local fast_approach=Config.fsm.fast_approach or 0;

local entry = function()
  print("BodyFSM: ".._NAME.." entry");
  t0 = Body.get_time();
  behavior.update();
end

local update = function()
  local t = Body.get_time();
  local ball=wcm.get_ball();
  local pose=wcm.get_pose();
  local ballR = math.sqrt(ball.x^2 + ball.y^2);

  --recalculate approach path when ball is far away
  if ballR>0.60 then
    --print("behavior update");
    behavior.update();
  end

  local role = gcm.get_team_role();
  local kickDir = wcm.get_kick_dir();

  --Force attacker for demo code
  if Config.fsm.playMode==1
    then role=1;
    end
  if role==0 then
    return "goalie";
  end

  local homePose;
  if (role == 2) then
    homePose = position.getDefenderHomePose();
  elseif (role==3) then
    homePose = position.getSupporterHomePose();
  else
    if Config.fsm.playMode~=3 or kickDir~=1 then --We don't care to turn when we do sidekick
      homePose = position.getAttackerHomePose();
--      homePose = position.getDirectAttackerHomePose();
    else
      homePose = position.getAttackerHomePose();
    end
  end

  --Field player cannot enter our penalty box
  --SJ:  We replace this with potential field around goalie

  --[[
    if role~=0 then
      goalDefend = wcm.get_goal_defend();
      homePose[1]=util.sign(goalDefend[1])*
      math.min(2.2,homePose[1]*util.sign(goalDefend[1]));
    end
  --]]

  local vx, vy, va;
  if role==1 then
    vx,vy,va=position.setAttackerVelocity(homePose);
  else
    vx,vy,va=position.setDefenderVelocity(homePose);
  end

  --Get pushed away if other robots are around
  local obstacle_num = wcm.get_obstacle_num();
  local obstacle_x = wcm.get_obstacle_x();
  local obstacle_y = wcm.get_obstacle_y();
  local obstacle_dist = wcm.get_obstacle_dist();
  local obstacle_role = wcm.get_obstacle_role();

  local avoid_own_team = Config.team.avoid_own_team or 0;
  local r_reject = 0;

  if avoid_own_team then
   for i=1,obstacle_num do
    --Role specific rejection radius
    if role==0 then --Goalie has the highest priority
      r_reject = 0.4;
    elseif role==1 then --Attacker
      if obstacle_role[i]==0 then --Our goalie
--        r_reject = 1.0;
        r_reject = 0.5;
      elseif obstacle_role[i]<4 then --Our team
        r_reject = 0.001;
      else
        r_reject = 0.001;
      end
    else --Defender and supporter
      if obstacle_role[i]<4 then --Our team
        if obstacle_role[i]==0 then --Our goalie
--          r_reject = 1.0;
          r_reject = 0.7;
        else
          r_reject = 0.6;
        end
      else --Opponent team
        r_reject = 0.6;
      end
    end

    if obstacle_dist[i]<r_reject then
      local v_reject = 0.2*math.exp(-(obstacle_dist[i]/r_reject)^2);
      vx = vx - obstacle_x[i]/obstacle_dist[i]*v_reject;
      vy = vy - obstacle_y[i]/obstacle_dist[i]*v_reject;
    end
   end
  end

  walk.set_velocity(vx,vy,va);

  if (t - ball.t > tLost) then
    return "ballLost";
  end
  if (t - t0 > timeout) then
    return "timeout";
  end

  local tBall=0.5;

  if Config.fsm.playMode~=3 then
    if ballR<rClose then
      return "ballClose";
    end
  end

--  if walk.ph>0.95 then
--    print(string.format("position error: %.3f %.3f %d\n",
--	homeRelative[1],homeRelative[2],homeRelative[3]*180/math.pi))
--    print("ballR:",ballR);
--    print(string.format("Velocity:%.2f %.2f %.2f",vx,vy,va));
--    print("VEL: ",veltype)
--  end

  local daPost = wcm.get_goal_daPost2();
  local daPostMargin = 15 * math.pi/180;
  local daPost1 = math.max(thClose[3],daPost/2 - daPostMargin);

  local uPose=vector.new({pose.x,pose.y,pose.a})
  local homeRelative = util.pose_relative(homePose, uPose);
  local angleToTurn = math.max(0, homeRelative[3] - daPost1);

--	homeRelative[1] = homeRelative[1]/2;
--	print(math.abs(homeRelative[1]),thClose[1]);
--	print(math.abs(homeRelative[2]),thClose[2]);
--	print(math.abs(homeRelative[3]),daPost1);
--	print(ballR,rClose);

  if math.abs(homeRelative[1])<thClose[1] and
      math.abs(homeRelative[2])<thClose[2] and
      math.abs(homeRelative[3])<daPost1 and
      ballR<rClose and t-ball.t<tBall then
    print("homeRelative done, ballR :", homeRelative[1],
                                        homeRelative[2],
                                        homeRelative[3]*180/math.pi,
                                        ballR);
    return "done";
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
