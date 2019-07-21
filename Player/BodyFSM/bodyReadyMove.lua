local _NAME = "bodyReadyMove";
local Body = require('Body')
local wcm = require('wcm')
local gcm = require('gcm')
local util = require('util')
local vector = require('vector')
local Config = require('Config')
local Team = require('Team')
local walk = require('walk')

local t0 = 0;

local maxStep = Config.fsm.bodyReady.maxStep;
local rClose = Config.fsm.bodyReady.thClose[1];
local thClose = Config.fsm.bodyReady.thClose[2];

--Init position for our kickoff
local initPosition1 = Config.world.initPosition1;
--Init position for opponents' kickoff
local initPosition2 = Config.world.initPosition2;

-- don't start moving right away
local tstart = Config.fsm.bodyReady.tStart or 5.0;

local phase=0; --0 for wait, 1 for approach, 2 for turn, 3 for end

local side_y = 0;

local getHomePose = function()
  local role=gcm.get_team_role();
  --Now role-based positioning
  local goal_defend=wcm.get_goal_defend();
  --role starts with 0

  local home;
  if gcm.get_game_kickoff() == 1 then
    home=vector.new({initPosition1[role+1][1],
                     initPosition1[role+1][2],
                     initPosition1[role+1][3]});
  else
    home=vector.new({initPosition2[role+1][1],
                     initPosition2[role+1][2],
                     initPosition2[role+1][3]});
  end

  --If we are on the other half and we are attacker,
  -- go around to avoid other players
  local pose = wcm.get_pose();
  if pose.y > 0.5 then
    side_y = 1;
  elseif pose.y<-0.5 then
    side_y = -1;
  end

  if math.abs(pose.x - goal_defend[1]) > 3.5
      and math.abs(home[2]) < 0.5 then
    home[2] = home[2] + side_y * 0.8;
  end

  --Goalie moves differently
  if role==0 and phase==1 then
    home=home*0.7;
  end;

  home=home*util.sign(goal_defend[1]);
  home[3]=goal_defend[3];
  return home;
end

local entry = function()
  print("BodyFSM: ".._NAME.." entry");
  phase=0;

  t0 = Body.get_time();
  Motion.event('standup')

  local pose = wcm.get_pose();
  if pose.y > 0 then
    side_y = 1;
  else
    side_y = -1;
  end

end

local update = function()
  local t = Body.get_time();
  local pose = wcm.get_pose();
  local home =getHomePose();
  local homeRelative = util.pose_relative(home, {pose.x, pose.y, pose.a});
  local rhome = math.sqrt(homeRelative[1]^2 + homeRelative[2]^2);
  local attackBearing = wcm.get_attack_bearing();
  local vx,vy,va=0,0,0;

  if phase==0 then
    if t - t0 < tstart then
      walk.set_velocity(0,0,0);
      return;
    else walk.start();
      phase=1;
    end
  elseif phase==1 then --Approach phase
    vx = maxStep * homeRelative[1]/rhome;
    vy = maxStep * homeRelative[2]/rhome;
    va = .2 * math.atan2(homeRelative[2], homeRelative[1]);
    if rhome < rClose then phase=2; end
  elseif phase==2 then --Turning phase, face center
    vx = maxStep * homeRelative[1]/rhome;
    vy = maxStep * homeRelative[2]/rhome;
    va = .2*attackBearing;
  end

  --Check the nearby obstacle
  local obstacle_num = wcm.get_obstacle_num();
  local obstacle_x = wcm.get_obstacle_x();
  local obstacle_y = wcm.get_obstacle_y();
  local obstacle_dist = wcm.get_obstacle_dist();


  --Now larger rejection radius
  local r_reject = 1.0;

  for i=1,obstacle_num do
--print(string.format("%d XYD:%.2f %.2f %.2f",
--i,obstacle_x[i],obstacle_y[i],obstacle_dist[i]))
    if obstacle_dist[i]<r_reject then
      local v_reject = 0.1*math.exp(-(obstacle_dist[i]/r_reject)^2);
      vx = vx - obstacle_x[i]/obstacle_dist[i]*v_reject;
      vy = vy - obstacle_y[i]/obstacle_dist[i]*v_reject;
    end
  end
  walk.set_velocity(vx, vy, va);

  if phase~=3 and rhome < rClose and
     math.abs(attackBearing)<thClose then
    walk.stop();
    phase=3;
  end
  --To prevent robot keep walking after falling down
  if phase==3 then
    walk.stop();
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
