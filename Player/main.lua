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
local count_ = 0;
local lcount_ = 0;
local tUpdate_ = unix.time();

--Start with PAUSED state
gcm.set_team_forced_role(0); --Don't force role
gcm.set_game_paused(1);
local waiting_ = 0;
local cur_role_;
if Config.game.role==1 then
  cur_role_ = 1; --Attacker
else
  cur_role_ = 0; --Default goalie
end

local update = function()
  count_ = count_ + 1;
  local t = Body.get_time();
  --Update battery info
  Body.get_battery_level();
  --wcm.set_robot_battery_level(Body.get_battery_level());
  vcm.set_camera_teambroadcast(1); --Turn on wireless team broadcast

  if waiting_ > 0 then --Waiting mode, check role change
    gcm.set_game_paused(1);
    if cur_role_ == 0 then
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

  if (count_ % 50 == 0) then
--    print('fps: '..(50 / (unix.time() - tUpdate_)));
    tUpdate_ = unix.time();
    Body.set_indicator_batteryLevel(Body.get_battery_level());
  end
end

return {
  update = update,
};
