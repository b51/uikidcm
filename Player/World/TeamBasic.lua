local Config  = require('Config');
local Body = require('Body');
local Comm = require('Comm');
local vector = require('vector');
local serialization = require('serialization');

local wcm = require('wcm');
local gcm = require('gcm');

local playerID_ = gcm.get_team_player_id();

local msgTimeout_ = Config.team.msgTimeout;
local nonAttackerPenalty_ = Config.team.nonAttackerPenalty;
local nonDefenderPenalty_ = Config.team.nonDefenderPenalty;

local role_ = -1;

local count_ = 0;

local state_ = {};
state_.teamNumber = gcm.get_team_number();
state_.id = playerID_;
state_.teamColor = gcm.get_team_color();
state_.time = Body.get_time();
state_.role = role_;
state_.pose = {x=0, y=0, a=0};
state_.ball = {t=0, x=1, y=0};
state_.attackBearing = 0.0;
state_.penalty = 0;
state_.tReceive = Body.get_time();

local states_ = {};
states_[playerID_] = state_;

local recv_msgs = function()
  while (Comm.size() > 0) do
    local t = serialization.deserialize(Comm.receive());
    if (t and (t.teamNumber) and (t.teamNumber == state_.teamNumber)
        and (t.id) and (t.id ~= playerID_)) then
      t.tReceive = Body.get_time();
      states_[t.id] = t;
    end
  end
end

local update_shm = function()
  -- update the shm values
  gcm.set_team_role(role_);
end

local get_player_id = function()
  return playerID_;
end

local get_role = function()
  return role_;
end

local set_role = function(r)
  if role_ ~= r then
    role_ = r;
    Body.set_indicator_role(role_);
    if role_ == 1 then
      -- attack
      print('Attack');
     -- print('------------------');
    elseif role_ == 2 then
      -- defend
      print('Defend');
    elseif role_ == 3 then
      -- support
      print('Support');
    elseif role_ == 0 then
      -- goalier
      print('Goalie');
    else
      -- no role
      print('ERROR: Unkown Role');
    end
  end
end

local min = function(t)
  local imin = 0;
  local tmin = math.huge;
  for i = 1,#t do
    if (t[i] < tmin) then
      tmin = t[i];
      imin = i;
    end
  end
  return tmin, imin;
end

local entry = function()
	Comm.init(Config.dev.ip_wireless, Config.dev.ip_wireless_port);
--	Comm.init(Config.dev.ip_wired,11111);
end

local update = function()
  count_ = count_ + 1;

  state_.time = Body.get_time();
  state_.teamNumber = gcm.get_team_number();
  state_.teamColor = gcm.get_team_color();
  state_.pose = wcm.get_pose();
  state_.ball = wcm.get_ball();
  state_.role = role_;
  state_.robotName = Config.game.robotName;

  --local labelB = vcm.get_image_labelB();
  local width = vcm.get_image_width()/2/Config.vision.scaleB;
  local height = vcm.get_image_height()/2/Config.vision.scaleB;
  local count = vcm.get_image_count();

  --state.labelB = serialization.serialize_label_rle(
	--labelB, width, height, 'uint8', 'labelB',count);

  state_.attackBearing = wcm.get_attack_bearing();
  if gcm.in_penalty() then
    state_.penalty = 1;
  else
    state_.penalty = 0;
  end

  if (math.mod(count, 1) == 0) then
  --print("before Comm.send");
    Comm.send(serialization.serialize(state_));
    --print("Comm.send done");
    --Copy of message sent out to other players
    state_.tReceive = Body.get_time();
    states_[playerID] = state_;
  end

  -- receive new messages
  recv_msgs();

  -- eta and defend distance calculation:
  local eta = {};
  local ddefend = {};
  local t = Body.get_time();
  for id = 1,4 do
    if not states_[id] or not states_[id].ball.x then
      -- no message from player have been received
      eta[id] = math.huge;
      ddefend[id] = math.huge;
    else
      -- eta to ball
      local rBall = math.sqrt(states_[id].ball.x^2 + states_[id].ball.y^2);
      local tBall = states_[id].time - states_[id].ball.t;
      -- if tBall > 5 then
      --    eta[id] = math.huge;
      -- else
      eta[id] = rBall/0.10 + 4*math.max(tBall-1.0,0);
      -- end
      -- distance to goal
      local dgoalPosition = vector.new(wcm.get_goal_defend());
      local pose = wcm.get_pose();
      ddefend[id] = math.sqrt((pose.x - dgoalPosition[1])^2 + (pose.y - dgoalPosition[2])^2);

      if (states_[id].role ~= 1) then
        -- Non attacker penalty:
        eta[id] = eta[id] + nonAttackerPenalty_;
      end
      if (states_[id].penalty > 0) or (Body.get_time() - states_[id].tReceive > msgTimeout_) then
        eta[id] = math.huge;
      end

      if (states_[id].role ~= 2) then
        -- Non defender penalty:
        ddefend[id] = ddefend[id] + 0.3;
      end
      if (states_[id].penalty > 0) or (t - states_[id].tReceive > msgTimeout_) then
        ddefend[id] = math.huge;
      end
    end
  end
  --[[
  if count % 100 == 0 then
    print('---------------');
    print('eta:');
    util.ptable(eta)
    print('ddefend:');
    util.ptable(ddefend)
    print('---------------');
  end
  --]]
  -- goalie never changes role
  if playerID_ ~= 1 then
    eta[1] = math.huge;
    ddefend[1] = math.huge;

    local minETA, minEtaID = min(eta);
    if minEtaID == playerID_ then
      -- attack
      set_role(1);
    else
      -- furthest player back is defender
      local minDDefID = 0;
      local minDDef = math.huge;
      for id = 2,4 do
        if id ~= minEtaID and ddefend[id] <= minDDef then
          minDDefID = id;
          minDDef = ddefend[id];
        end
      end
      if minDDefID == playerID_ then
        -- defense
        set_role(2);
      else
        -- support
        set_role(3);
      end
    end
  end

  -- update shm
  update_shm()
end

local exit = function()
end

set_role(playerID_-1);

return {
  entry = entry,
  update = update,
  exit = exit,
};
