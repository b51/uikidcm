package.cpath = "Lib/?.so;"..package.cpath;
package.path = "Lib/?.lua;"..package.path;
package.path = "Config/?.lua;"..package.path;
package.path = "Dev/?.lua;"..package.path;
package.path = "Util/?.lua;"..package.path;
local Body = require('MOSBody')
local unix = require('unix');
local util = require('util');

local count_ = 0;

--[[
local shm = require('shm');
local carray = require('carray')
local sensorShm = shm.open('dcmSensor');
local sensor = {};
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

for k,v in sensorShm.next, sensorShm do
  sensor[k] = carray.cast(sensorShm:pointer(k));
  _ENV["get_sensor_"..k] =
    function(index)
      return get_sensor_shm(k, index);
    end
end
--]]

while (true) do
  Body.set_state_sensorEnable(count_ % 2);
  local enable = Body.get_state_sensorEnable();
  print(enable[1]);
  count_ = count_ + 1;
  unix.usleep(5 * 1e3);
end
