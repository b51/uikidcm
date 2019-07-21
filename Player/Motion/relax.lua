local _NAME = "relax";
local vector = require('vector')
local Body = require('Body')
local Config = require('Config')
local Kinematics = require('Kinematics')
-- TODO(b51): Actually this file does nothing in MOS

local t0 = 0;
local timeout = 1.0;
local footX = Config.walk.footX or 0;
local footY = Config.walk.footY;
local supportX = Config.walk.supportX;
local pLLeg = vector.new({-supportX , footY, 0, 0,0,0});
local pRLeg = vector.new({-supportX , -footY, 0, 0,0,0});
local hip_pitch_target = -20*math.pi/180;
local ankle_pitch_target = -95*math.pi/180;
local ankle_pitch_target = -105*math.pi/180;
local knee_pitch_target = 120*math.pi/180;

local entry = function()
  print("Motion: ".._NAME.." entry");

  t0 = Body.get_time();
  Body.set_head_hardness(0);
  Body.set_larm_hardness(0);
  Body.set_rarm_hardness(0);
  Body.set_lleg_command({0,0,hip_pitch_target,0,0,0});
  Body.set_rleg_command({0,0,hip_pitch_target,0,0,0});
  Body.set_lleg_hardness({0.6,0.6,0.6,0,0,0});
  Body.set_rleg_hardness({0.6,0.6,0.6,0,0,0});
  Body.set_syncread_enable(1);
end

local update = function()
  local t = Body.get_time();

  --Only reset leg positons, not arm positions (for waiting players)
  local qSensor = Body.get_sensor_position();
  qSensor[6],qSensor[7]=0,0;
  qSensor[12],qSensor[13]=0,0;
  qSensor[8],qSensor[14]=hip_pitch_target,hip_pitch_target;

  qLLeg = {0,0,hip_pitch_target, qSensor[9],qSensor[10],qSensor[11]};
  qRReg = {0,0,hip_pitch_target, qSensor[15],qSensor[16],qSensor[17]};

  Body.set_lleg_command(qLLeg);
  Body.set_rleg_command(qRLeg);

  --update vcm body information
  local qLLeg = Body.get_lleg_position();
  local qRLeg = Body.get_rleg_position();
  local dpLLeg = Kinematics.torso_lleg(qLLeg);
  local dpRLeg = Kinematics.torso_rleg(qRLeg);

  local pTorsoL=pLLeg+dpLLeg;
  local pTorsoR=pRLeg+dpRLeg;
  local pTorso=(pTorsoL+pTorsoR)*0.5;
    --[[vcm.set_camera_bodyHeight(pTorso[3]);----------------------------------------123456Ô]áŒ
  vcm.set_camera_bodyTilt(pTorso[5]);--]]----------------------------------------123456Ô]áŒ
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
};
