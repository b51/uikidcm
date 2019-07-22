-- Add the required paths
cwd = os.getenv('PWD')
package.cpath = cwd.."/Lib/?.so;"..package.cpath;
package.path = cwd.."/Util/?.lua;"..package.path;
package.path = cwd.."/Config/?.lua;"..package.path;
package.path = cwd.."/Lib/?.lua;"..package.path;
package.path = cwd.."/Dev/?.lua;"..package.path;
package.path = cwd.."/World/?.lua;"..package.path;
package.path = cwd.."/Vision/?.lua;"..package.path;
package.path = cwd.."/Motion/?.lua;"..package.path;

local unix = require('unix');
local shm = require('shm');
local dcm = require('MOSCommManager');
local vcm = require('vcm') --Shared memory is created here, and ready for access

print('Starting device comm manager...');
dcm.entry()

-- I don't think this should be here for shm management?
-- Shouldn't these just be dcm.something acces funcitons?
sensorShm = shm.open('dcmSensor');
actuatorShm = shm.open('dcmActuator');

print('Running controller');
local loop = true;
local count = 0;
local t0 = unix.time();

--for testing
dcm.actuator.readType[1]=0;--Read Head only
dcm.actuator.battTest[1]=0; --Battery test disable

local fpsdesired=100; --100 HZ cap on refresh rate
local ncount=200;

local t_timing=unix.time();
while (loop) do
  count = count + 1;
  local t1 = unix.time();
  local tPassed=math.max(math.min(t1 - t_timing,0.010), 0); --Check for timer overflow
  local readtype = actuatorShm:get('readType') ;
  if readtype == 0 then ncount=200;
    else ncount = 40;
  end

  t_timing=t1;
  dcm.update()

  if (count % ncount == 0) then
    os.execute("clear")
    t0 = t1;
  end
  unix.usleep(5000);
end

dcm.exit()
