require('unix');
require('shm');

local cwd = unix.getcwd();
package.path = cwd.."/../Util/?.lua;"..package.path; --For Transform
package.path = cwd.."/../Vision/?.lua;"..package.path; --For vcm

dcm = require('OPCommManager');
print('Starting device comm manager...');


require('vcm') --Shared memory is created here, and ready for access
loop = true;
count = 0;
ncount=10000;
dcm.entry()
while (loop) do
   count = count + 1;
   if count>ncount then
      count=0;
   end 
   dcm.update()
end

dcm.exit()
