package.cpath = "../Lib/?.so;"..package.path;
package.path = "../Lib/?.lua;"..package.path;
package.path = "../Config/?.lua;"..package.path;
package.path = "../Vision/?.lua;"..package.path;
package.path = "../Dev/?.lua;"..package.path;
package.path = "../Motion/?.lua;"..package.path;
package.path = "../Util/?.lua;"..package.path;
package.path = "../Motion/Walk/?.lua;"..package.path;

local walk = require('BasicWalk');
local standstill = require('standstill');

print("1. walk.active: ", walk.active)
standstill.entry();
print("1. walk.active: ", walk.active)
print("1. walk.active: ", walk.active)
print("1. walk.active: ", walk.active)
