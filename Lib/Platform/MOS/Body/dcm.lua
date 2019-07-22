-- This file used for run_main.lua to get dcm variable values
local shm = require("shm");
local carray = require("carray");

local _ENV = {print = print, type = type,};

sensorShm = shm.open('dcmSensor');
actuatorShm = shm.open('dcmActuator');
stateShm = shm.open('dcmState');--123456
paraShm = shm.open('dcmParameter');--123456

local dcm = {};
local sensor = {};
local actuator = {};
local state = {};--123456
local para = {};--123456

local get_sensor_shm = function(shmkey, index)
  if (index) then
    return sensor[shmkey][index];
  else
    local t = {};
    for i = 1,#sensor[shmkey] do
      t[i] = sensor[shmkey][i];
    end
    return t;
  end
end

local set_actuator_shm = function(shmkey, val, index)
  index = index or 1;
  if (type(val) == "number") then
    actuator[shmkey][index] = val;
  elseif (type(val) == "table") then
    for i = 1,#val do
      actuator[shmkey][index+i-1] = val[i];
    end
  end
end

local get_state_shm = function(shmkey, index)--123456
  if (index) then
    return state[shmkey][index];
  else
    local t = {};
    for i = 1,#state[shmkey] do
      t[i] = state[shmkey][i];
    end
    return t;
  end
end--123456

local set_state_shm = function(shmkey, val, index)--123456
  index = index or 1;
  if (type(val) == "number") then
    state[shmkey][index] = val;
  elseif (type(val) == "table") then
    for i = 1,#val do
      state[shmkey][index+i-1] = val[i];
    end
  end
end--123456

local get_para_shm = function(shmkey, index)--123456
  if (index) then
    return para[shmkey][index];
  else
    local t = {};
    for i = 1,#para[shmkey] do
      t[i] = para[shmkey][i];
    end
    return t;
  end
end--123456

local set_para_shm = function(shmkey, val, index)--123456
  index = index or 1;
  if (type(val) == "number") then
    para[shmkey][index] = val;
  elseif (type(val) == "table") then
    for i = 1,#val do
      para[shmkey][index+i-1] = val[i];
    end
  end
end--123456

for k,v in sensorShm.next, sensorShm do
  sensor[k] = carray.cast(sensorShm:pointer(k));
  _ENV["get_sensor_"..k] =
    function(index)
      return get_sensor_shm(k, index);
    end
end

for k,v in actuatorShm.next, actuatorShm do
  actuator[k] = carray.cast(actuatorShm:pointer(k));
  _ENV["set_actuator_"..k] =
    function(val, index)
      return set_actuator_shm(k, val, index);
    end
end

for k,v in stateShm.next, stateShm do--123456
  state[k] = carray.cast(stateShm:pointer(k));
  _ENV["get_state_"..k] =
    function(index)
      return get_state_shm(k, index);
    end
end--123456

for k,v in stateShm.next, stateShm do--123456
  state[k] = carray.cast(stateShm:pointer(k));
  _ENV["set_state_"..k] =
    function(val, index)
      return set_state_shm(k, val, index);
    end
end--123456

for k,v in paraShm.next, paraShm do--123456
  para[k] = carray.cast(paraShm:pointer(k));
  _ENV["get_para_"..k] =
    function(index)
      return get_para_shm(k, index);
    end
end--123456

for k,v in paraShm.next, paraShm do--123456
  para[k] = carray.cast(paraShm:pointer(k));
  _ENV["set_para_"..k] =
    function(val, index)
      return set_para_shm(k, val, index);
    end
end--123456

dcm = _ENV;

local nJoint = #sensor.position; --From DLC

-- Initialize actuator commands and positions
for i = 1,nJoint do
  actuator.command[i] = sensor.position[i];
--  actuator.position[i] = sensor.position[i];
end

return dcm;
