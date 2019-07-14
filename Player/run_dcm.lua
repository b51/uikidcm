-- Add the required paths
cwd = '.';
computer = os.getenv('COMPUTER') or "";
if (string.find(computer, "Darwin")) then
   -- MacOS X uses .dylib:
   package.cpath = cwd.."/Lib/?.dylib;"..package.cpath;
else
   package.cpath = cwd.."/Lib/?.so;"..package.cpath;
end
package.path = cwd.."/Vision/?.lua;"..package.path;
package.path = cwd.."/Util/?.lua;"..package.path;
package.path = cwd.."/Config/?.lua;"..package.path;
package.path = cwd.."/Lib/?.lua;"..package.path;
package.path = cwd.."/Dev/?.lua;"..package.path;
package.path = cwd.."/World/?.lua;"..package.path;
package.path = cwd.."/Vision/?.lua;"..package.path;
package.path = cwd.."/Motion/?.lua;"..package.path;


require('unix');
require('shm');
dcm = require('OPCommManager');
print('Starting device comm manager...');
dcm.entry()

-- I don't think this should be here for shm management?
-- Shouldn't these just be dcm.something acces funcitons?
sensorShm = shm.open('dcmSensor');
actuatorShm = shm.open('dcmActuator');

require('vcm') --Shared memory is created here, and ready for access

print('Running controller');
loop = true;
count = 0;
t0 = unix.time();

--for testing
dcm.actuator.readType[1]=0;--Read Head only
dcm.actuator.battTest[1]=0; --Battery test disable

fpsdesired=100; --100 HZ cap on refresh rate
ncount=200;

t_timing=unix.time();
while (loop) do
   count = count + 1;
   local t1 = unix.time();
   local tPassed=math.max(math.min(t1-t_timing,0.010),0); --Check for timer overflow
   readtype= actuatorShm:get('readType') ;
   if readtype==0 then ncount=200;
     else ncount = 40;
   end

   if 1/fpsdesired > tPassed then
--      unix.usleep(1E6*(1/fpsdesired - tPassed));
   end
   t_timing=t1;
   dcm.update()


--   pos=vector.new(sensorShm:get('position'))*180/math.pi;
--   print(string.format("Position:\n Head: %f %f",pos[1],pos[2]));


   if (count % ncount == 0) then
      os.execute("clear")
      local iangle=vector.new(sensorShm:get('imuAngle'))*180/math.pi;
      t0 = t1;

   end
   unix.usleep(5000);
end

dcm.exit()
