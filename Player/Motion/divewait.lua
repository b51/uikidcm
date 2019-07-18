local vector = require('vector')
local mcm = require('mcm')
local Body = require('Body')
local Config = require('Config')
local Kinematics = require('Kinematics')
local walk = require('walk')

local active = true;
local t0 = 0;

local supportX = Config.walk.supportX;
local bodyHeight = Config.stance.bodyHeightDive or 0.25;
local bodyTilt = Config.stance.bodyTiltDive or 0;

-- Max change in postion6D to reach stance:
local dpLimit=Config.stance.dpLimitDive or 
                vector.new({.1,.01,.03,.1,.3,.1});

local tFinish=0;
local tStartWait=0.2;
local tEndWait=0.1;
local tStart=0;
local finished=false;
local started = false;
local pLLeg = {};
local pRLeg = {};

local entry = function()
  print("Motion: divewait entry");

  local footX = mcm.get_footX();
  local footY = Config.walk.footY;
  -- Final stance foot position6D
  pTorsoTarget = vector.new({0, 0, bodyHeight, 0,bodyTilt,0});
  pLLeg = vector.new({-supportX + footX, footY, 0, 0,0,0});
  pRLeg = vector.new({-supportX + footX, -footY, 0, 0,0,0});

  walk.stop();
  started=false;
  finished=false;

--  Body.set_head_hardness(.5);
  Body.set_larm_hardness(.1);
  Body.set_rarm_hardness(.1);
  t0=Body.get_time();

end

local update = function()
  local t = Body.get_time();
  if walk.active then
    -- walk.update();   --tse
     t0=Body.get_time();
     return;
  end
  if finished then
    return;
  end

  local dt = t - t0;
  if not started then
   --For OP, wait a bit to read joint readings
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
      Body.set_lleg_hardness(1);
      Body.set_rleg_hardness(1);
      t0 = Body.get_time();
      tStart=t;
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

  --[[vcm.set_camera_bodyHeight(pTorso[3]);------------123456Ô]áŒ
      vcm.set_camera_bodyTilt(pTorso[5]);--]]----------123456Ô]áŒ
  -- print("BodyHeight/Tilt:",pTorso[3],pTorso[5]*180/math.pi)

  local q = Kinematics.inverse_legs(pLLeg, pRLeg, pTorso, 0);
  Body.set_lleg_command(q);

  if (tol) then
    if tFinish==0 then
      tFinish=t;
    else
      if t-tFinish>tEndWait then
        finished=true;
        print("Sit done, time elapsed",t-tStart)
      end
    end
  end
end

local exit = function()
  Body.set_syncread_enable(1);
end

return {
  _NAME = "divewait",
  entry = entry,
  update = update,
  exit = exit,
};
