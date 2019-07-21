local unix = require('unix');
local vector = require('vector');
local dcm = require('dcm');
local util = require('util');

local MOSBody = {};
local _ENV = {print = print,
              pairs = pairs,
              type = type,
              table = table,};

for k,v in pairs(dcm) do
  _ENV[k] = v;
end
MOSBody = _ENV;

local indexHead = 1;			--Head: 1 2
local nJointHead = 2;
local indexLArm = 3;			--LArm: 3 4 5
local nJointLArm = 3;
local indexLLeg = 6;			--LLeg: 6 7 8 9 10 11
local nJointLLeg = 6;
local indexRLeg = 12;			--RLeg: 12 13 14 15 16 17
local nJointRLeg = 6;
local indexRArm = 18;			--RArm: 18 19 20
local nJointRArm = 3;

local nJoint = nJointHead + nJointLArm + nJointLLeg + nJointRLeg + nJointRArm;

--Aux servo (for gripper / etc)
local indexAux= 21;
local nJointAux=nJoint-20;

MOSBody.get_time = unix.time;

MOSBody.update = function()
end

-- setup convience functions
MOSBody.get_head_position = function()
  local q = get_sensor_position();
  return {table.unpack(q, indexHead, indexHead+nJointHead-1)};
end

MOSBody.get_larm_position = function()
  local q = get_sensor_position();
  return {table.unpack(q, indexLArm, indexLArm+nJointLArm-1)};
end

MOSBody.get_rarm_position = function()
  local q = get_sensor_position();
  return {table.unpack(q, indexRArm, indexRArm+nJointRArm-1)};
end

MOSBody.get_lleg_position = function()
  local q = get_sensor_position();
  return {table.unpack(q, indexLLeg, indexLLeg+nJointLLeg-1)};
end

MOSBody.get_rleg_position = function()
  local q = get_sensor_position();
  return {table.unpack(q, indexRLeg, indexRLeg+nJointRLeg-1)};
end

MOSBody.set_waist_hardness = function(val)
end

MOSBody.set_lleg_pid = function(val)
  --Usage: {P gain, I gain, D gain}
  local p_param = val[1]*vector.ones(nJointLLeg);
  local i_param = val[2]*vector.ones(nJointLLeg);
  local d_param = val[3]*vector.ones(nJointLLeg);

  set_actuator_p_param(p_param,indexLLeg);
  set_actuator_i_param(i_param,indexLLeg);
  set_actuator_d_param(d_param,indexLLeg);
  set_actuator_slopeChanged(1,1);
end

MOSBody.set_rleg_pid = function(val)
  --Usage: {P gain, I gain, D gain}
  local p_param = val[1]*vector.ones(nJointRLeg);
  local i_param = val[2]*vector.ones(nJointRLeg);
  local d_param = val[3]*vector.ones(nJointRLeg);

  set_actuator_p_param(p_param,indexRLeg);
  set_actuator_i_param(i_param,indexRLeg);
  set_actuator_d_param(d_param,indexRLeg);

  set_actuator_slopeChanged(1,1);
end

MOSBody.set_body_hardness = function(val)
  if (type(val) == "number") then
    val = val*vector.ones(nJoint);
  end
  set_actuator_hardness(val);
  set_actuator_hardnessChanged(1);
end

MOSBody.set_head_hardness = function(val)
  if (type(val) == "number") then
    val = val*vector.ones(nJointHead);
  end
  set_actuator_hardness(val, indexHead);
  set_actuator_hardnessChanged(1);
end

MOSBody.set_larm_hardness = function(val)
  if (type(val) == "number") then
    val = val*vector.ones(nJointLArm);
  end
  set_actuator_hardness(val, indexLArm);
  set_actuator_hardnessChanged(1);
end

MOSBody.set_rarm_hardness = function(val)
  if (type(val) == "number") then
    val = val*vector.ones(nJointRArm);
  end
  set_actuator_hardness(val, indexRArm);
  set_actuator_hardnessChanged(1);
end

MOSBody.set_lleg_hardness = function(val)
  if (type(val) == "number") then
    val = val*vector.ones(nJointLLeg);
  end
  set_actuator_hardness(val, indexLLeg);
  set_actuator_hardnessChanged(1);
end

MOSBody.set_rleg_hardness = function(val)
  if (type(val) == "number") then
    val = val*vector.ones(nJointRLeg);
  end
  set_actuator_hardness(val, indexRLeg);
  set_actuator_hardnessChanged(1);
end

MOSBody.set_aux_hardness = function(val)
  if nJointAux==0 then
    return;
  end
  if (type(val) == "number") then
    val = val*vector.ones(nJointAux);
  end
  set_actuator_hardness(val, indexAux);
  set_actuator_hardnessChanged(1);
end

MOSBody.set_waist_command = function(val)
  --Do nothing
end

MOSBody.set_head_command = function(val)
  set_actuator_command(val, indexHead);
end

MOSBody.set_lleg_command = function(val)
  set_actuator_command(val, indexLLeg);
end

MOSBody.set_rleg_command = function(val)
  set_actuator_command(val, indexRLeg);
end

MOSBody.set_larm_command = function(val)
  set_actuator_command(val, indexLArm);
end

MOSBody.set_rarm_command = function(val)
  set_actuator_command(val, indexRArm);
end

MOSBody.set_aux_command = function(val)
  if nJointAux==0 then return;end
  set_actuator_command(val, indexAux);
end

--Added by SJ
MOSBody.set_syncread_enable = function(val)
  set_actuator_readType(val);
end

MOSBody.set_lleg_slope = function(val)
  if (type(val) == "number") then
    val = val*vector.ones(nJointLLeg);
  end
  set_actuator_gain(val, indexLLeg);
  set_actuator_gainChanged(1,1);
end

MOSBody.set_rleg_slope = function(val)
  --Now val==0 for regular p gain
  --    val==1 for stiff p gain (for kicking

  if (type(val) == "number") then
    val = val*vector.ones(nJointRLeg);
  end
  set_actuator_gain(val, indexRLeg);
  set_actuator_gainChanged(1,1);
end

MOSBody.set_torque_enable = function(val)
  set_actuator_torqueEnable(val);
  set_actuator_torqueEnableChanged(1);
end

-- Set API compliance functions
MOSBody.get_sensor_imuGyr0 = function()
  return vector.zeros(3)
end

--Added function for nao
--returns gyro values in RPY, degree per seconds unit
MOSBody.get_sensor_imuGyrRPY = function()
  return get_sensor_imuGyr();
end

MOSBody.set_indicator_state = function(color)
end

MOSBody.set_indicator_team = function(teamColor)
end

MOSBody.set_indicator_kickoff = function(kickoff)
end

MOSBody.set_indicator_batteryLevel = function(level)
end

MOSBody.set_indicator_role = function(role)
end

MOSBody.set_indicator_ball = function(color)
  -- color is a 3 element vector
  -- convention is all zero indicates no detection
  --Body.set_actuator_headled({0,0,0});
  color[1] = 31*color[1];
  color[2] = 31*color[2];
  color[3] = 31*color[3];
  Body.set_actuator_eyeled( color );
end

MOSBody.set_indicator_goal = function(color)
  -- color is a 3 element vector
  -- convention is all zero indicates no detection
  color[1] = 31*color[1];
  color[2] = 31*color[2];
  color[3] = 31*color[3];
  Body.set_actuator_headled(color);
  --Body.set_actuator_eyeled({0,0,0});
end

MOSBody.get_battery_level = function()
  local batt = get_sensor_battery();
  return batt[1]/10;
end

MOSBody.get_change_state = function()
  local b = get_sensor_button();
  return b[1];
end

MOSBody.get_change_enable = function()
  return 0;
end

MOSBody.get_change_team = function()
  return 0;
end

MOSBody.get_change_role = function()
  local b = get_sensor_button();
  return b[2];
end

MOSBody.get_change_kickoff = function()
  return 0;
end

-- OP doe not have the UltraSound device
MOSBody.set_actuator_us = function()
end

MOSBody.get_sensor_usLeft = function()
  return vector.zeros(10);
end

MOSBody.get_sensor_usRight = function()
  return vector.zeros(10);
end

MOSBody.calibrate = function(count)
  return true
end

MOSBody.get_sensor_fsrRight = function()
  local fsr = {0};
  return fsr
end

MOSBody.get_sensor_fsrLeft = function()
  local fsr = {0};
  return fsr
end

--util.ptable(MOSBody);
return MOSBody;
