local Config = require('Config')
local vector = require('vector')
local Kinematics = require('Kinematics')
local Body = require('Body')
local walk = require('walk')
local mcm = require('mcm')

local started = false;
local active = true;
local t0 = 0;

local footY = Config.walk.footY;
local supportX = Config.walk.supportX;

local bodyHeightSit = Config.stance.bodyHeightSit;
local bodyTiltSit = Config.stance.bodyTiltSit or 0;

-- Final stance foot position6D
local pLLeg = vector.new({-supportX, footY, 0, 0,0,0});
local pRLeg = vector.new({-supportX, -footY, 0, 0,0,0});

local qLArm = Config.stance.qLArmSit;
local qRArm = Config.stance.qRArmSit;

local tStartWait = 0.2;
local tStart=0;

local entry = function()
  print("Motion SM: sit entry");
  walk.stop();
  started=false;
  --This makes the robot look up and see goalposts while sitting down
  Body.set_head_command({0,-20*math.pi/180});
  Body.set_head_hardness(.5);
  Body.set_larm_hardness(.1);
  Body.set_rarm_hardness(.1);
  t0=Body.get_time();
  Body.set_syncread_enable(1);
  walk.stance_reset();--123456停止walk（walk-->sit）
  Body.set_para_velocity(vector.new({0,0,0}));
  Body.set_state_gaitValid(1);------------123456站立 开始（复位？）
end

local update = function()
  local t = Body.get_time();
  if walk.active then
     walk.update();
     t0=Body.get_time();
     return;
  end
  --For OP, wait a bit to read joint readings
  if not started then
    if t-t0>tStartWait then
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
      Body.set_lleg_hardness(0.7);
      Body.set_rleg_hardness(0.7);
      t0 = Body.get_time();
      Body.set_syncread_enable(0);

      if qLArm then
        Body.set_larm_command(qLArm);
        Body.set_rarm_command(qRArm);
        Body.set_larm_hardness(0.4);
        Body.set_rarm_hardness(0.4);
      end
    else
      Body.set_syncread_enable(1);
      return;
    end
  end

  local dt = t - t0;
  t0 = t;

  local tol = true;
  local tolLimit = 1e-6;
  tol = false;--123456等待站立完成（后于）
  vel = Body.get_sensor_velocity();--123456等待站立完成（后于）
  if (vel[1] == 0 and vel[2] == 0 and vel[3] == 0) then
    tol = true;
  end--123456等待站立完成（后于）
  if (tol) then
    print("Sit done, time elapsed",t-tStart)
    return "done"
  end
end

local exit = function()
end

return {
  entry = entry,
  update = update,
  exit = exit,
};
