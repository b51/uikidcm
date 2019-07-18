local vcm = require('vcm')
local mcm = require('mcm')
local vector = require('vector')
local walk = require('walk')
local Transform = require('Transform')
local Body = require('Body')
local Kinematics = require('Kinematics')
local Config = require('Config')

local t0 = 0;

local footY = Config.walk.footY;
local supportX = Config.walk.supportX;
local bodyHeight = Config.walk.bodyHeight;
local bodyTilt = Config.stance.bodyTiltStance or 0;
local qLArm = Config.walk.qLArm;
local qRArm = Config.walk.qRArm;

-- Max change in position6D to reach stance:
local dpLimit = Config.stance.dpLimitStance or vector.new({.04, .03, .07, .4, .4, .4});

local tFinish=0;
local tStartWait=0.2;
local tEndWait=0.1;
local tStart=0;

local finished=false;

local hardnessLeg = Config.stance.hardnessLeg or 1;

local pTorsoTarget = {};
local pLLeg = {};
local pRLeg = {};
local started = false;

local entry = function()
  print("Motion: standstill entry");
  -- Final stance foot position6D
  pTorsoTarget = vector.new({0, 0, bodyHeight, 0,bodyTilt,0});
  pLLeg = vector.new({-supportX + mcm.get_footX(), footY, 0, 0,0,0});
  pRLeg = vector.new({-supportX + mcm.get_footX(), -footY, 0, 0,0,0});

  Body.set_syncread_enable(1);
  started=false;
  finished=false;

  tFinish=0;

  Body.set_head_command({0,0});
  Body.set_head_hardness(.5);

  Body.set_larm_command(qLArm);
  Body.set_rarm_command(qRArm);

  Body.set_larm_hardness(.1);
  Body.set_rarm_hardness(.1);

  Body.set_waist_command(0);
  Body.set_waist_hardness(1);

  t0 = Body.get_time();
  Body.set_para_velocity(vector.new({0,0,0}));------------123456站立 开始（复位？）
  Body.set_state_gaitValid(1);------------123456站立 开始（复位？）
  walk.active=false;
end

local update = function()
  local t = Body.get_time();
  local dt = t - t0;
  if finished then return; end

  --Wait a bit to read joint readings
  if not started then
    if dt>tStartWait then
      started=true;

      local qLLeg = Body.get_lleg_position();
      local qRLeg = Body.get_rleg_position();
      local dpLLeg = Kinematics.torso_lleg(qLLeg);
      local dpRLeg = Kinematics.torso_rleg(qRLeg);

      local pTorsoL=pLLeg+dpLLeg;
      local pTorsoR=pRLeg+dpRLeg;
      local pTorso=(pTorsoL+pTorsoR)*0.5;

      Body.set_lleg_command(qLLeg);
      Body.set_rleg_command(qRLeg);
      Body.set_lleg_hardness(hardnessLeg);
      Body.set_rleg_hardness(hardnessLeg);
      t0 = Body.get_time();
      tStart=t0;
      Body.set_syncread_enable(0);
    else
      Body.set_syncread_enable(1);
      return;
    end
  end


  t0 = t;
  local tol = true;
  local tolLimit = 1e-6;
  local dpDeltaMax = dt*dpLimit;

  local dpTorso = pTorsoTarget - pTorso;
  for i = 1,6 do
    if (math.abs(dpTorso[i]) > tolLimit) then
      tol = false;
      if (dpTorso[i] > dpDeltaMax[i]) then
        dpTorso[i] = dpDeltaMax[i];
      elseif (dpTorso[i] < -dpDeltaMax[i]) then
        dpTorso[i] = -dpDeltaMax[i];
      end
    end
  end

  pTorso=pTorso+dpTorso;

  --[[vcm.set_camera_bodyHeight(pTorso[3]);----------------------------------------123456註釋
      vcm.set_camera_bodyTilt(pTorso[5]);--]]----------------------------------------123456註釋
  --print("BodyHeight/Tilt:",pTorso[3],pTorso[5]*180/math.pi)

  local q = Kinematics.inverse_legs(pLLeg, pRLeg, pTorso, 0);
  Body.set_lleg_command(q);

  if (tol) then
    if tFinish==0 then
      tFinish=t;
    else
      local vel = Body.get_sensor_velocity();--123456等待站立完成（后于）
      if t-tFinish>tEndWait and vel[1] == 0 and vel[2] == 0 and vel[3] == 0 then
        finished=true;
        print("Stand done, time elapsed",t-tStart)
        return "done"
      end
    end
  end
end

local exit = function()
end

return {
  _NAME = "standstill",
  entry = entry,
  update = update,
  exit = exit,
};
