-- Get Platform for package path
cwd = os.getenv('PWD');

package.path = cwd .. '/?.lua;' .. package.path;
package.path = cwd .. '/Util/?.lua;' .. package.path;
package.path = cwd .. '/Config/?.lua;' .. package.path;
package.path = cwd .. '/Lib/?.lua;' .. package.path;
package.path = cwd .. '/Dev/?.lua;' .. package.path;
package.path = cwd .. '/Motion/?.lua;' .. package.path;
package.path = cwd .. '/Motion/keyframes/?.lua;' .. package.path;
package.path = cwd .. '/Motion/Walk/?.lua;' .. package.path;
package.path = cwd .. '/Vision/?.lua;' .. package.path;
package.path = cwd .. '/World/?.lua;' .. package.path;

local unix = require('unix');
local util = require('util');
local getch = require('getch');
local shm = require('shm');
local vcm = require('vcm');
local gcm = require('gcm');
local wcm = require('wcm');
local mcm = require('mcm');
local vector = require('vector');
local Body = require('Body');
local Motion = require('Motion');
local Config = require('Config');

gcm.say_id();

Motion.entry();

local init = false;
local calibrating = false;
local ready = true;
 
local initToggle = true;

--SJ: Now we use a SINGLE state machine for goalie and attacker
package.path = cwd..'/BodyFSM/?.lua;'..package.path;
package.path = cwd..'/HeadFSM/?.lua;'..package.path;
package.path = cwd..'/GameFSM/?.lua;'..package.path;
local BodyFSM = require('BodyFSM')
local HeadFSM = require('HeadFSM')
local GameFSM = require('GameFSM')

BodyFSM.entry();
HeadFSM.entry();
GameFSM.entry();

-- main loop
count = 0;
lcount = 0;
tUpdate = unix.time();

--Start with PAUSED state
gcm.set_team_forced_role(0); --Don't force role
gcm.set_game_paused(1);
waiting = 0;
if Config.game.role==1 then
  cur_role = 1; --Attacker
else
  cur_role = 0; --Default goalie
end

function update()
  count = count + 1;
  t = Body.get_time();
  --Update battery info
  wcm.set_robot_battery_level(Body.get_battery_level());
  vcm.set_camera_teambroadcast(1); --Turn on wireless team broadcast

  if waiting>0 then --Waiting mode, check role change
    gcm.set_game_paused(1);
    if cur_role==0 then
      gcm.set_team_role(5); --Reserve goalie
      Body.set_indicator_ball({0,0,1});

      --Both arm up for goalie
      Body.set_rarm_command({0,0,-math.pi/2});
      Body.set_rarm_hardness({0,0,0.5});
      Body.set_larm_command({0,0,-math.pi/2});
      Body.set_larm_hardness({0,0,0.5});

    else
      gcm.set_team_role(4); --Reserve player
      Body.set_indicator_ball({1,1,1});

      --One arm up for goalie
      Body.set_rarm_command({0,0,0});
      Body.set_rarm_hardness({0,0,0.5});
      Body.set_larm_command({0,0,-math.pi/2});
      Body.set_larm_hardness({0,0,0.5});
    end

    Motion.update();
    Body.update();

  else --Playing mode, update state machines
    gcm.set_game_paused(0);
    GameFSM.update();
    BodyFSM.update();
    HeadFSM.update();
    Motion.update();
    Body.update();
  end

  local dcount = 50;
  if (count % 50 == 0) then
--    print('fps: '..(50 / (unix.time() - tUpdate)));
    tUpdate = unix.time();
    Body.set_indicator_batteryLevel(Body.get_battery_level());
  end

end

if( darwin ) then
  local tDelay = 0.005 * 1E6; -- Loop every 5ms
  while 1 do
    update();
    unix.usleep(tDelay);
  end
end
