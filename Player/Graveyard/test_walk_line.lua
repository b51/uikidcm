module(... or '', package.seeall)

-- Get Platform for package path
cwd = '.';
local platform = os.getenv('PLATFORM') or '';
if (string.find(platform,'webots')) then cwd = cwd .. '/Player';
end

-- Get Computer for Lib suffix
local computer = os.getenv('COMPUTER') or '';
if (string.find(computer, 'Darwin')) then
  -- MacOS X uses .dylib:
  package.cpath = cwd .. '/Lib/?.dylib;' .. package.cpath;
else
  package.cpath = cwd .. '/Lib/?.so;' .. package.cpath;
end

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

require('unix')
require('Config')
require('shm')
require('vector')
require('mcm')
require('Speak')
require('getch')
require('Body')
require('Motion')
require('dive')

require('cognition')
require('vcm')

require('grip')
Motion.entry();
--World.entry();
--Vision.entry();
darwin = false;
webots = false;

-- Enable OP specific
if(Config.platform.name == 'OP') then
  darwin = true;
  --SJ: OP specific initialization posing (to prevent twisting)
--  Body.set_body_hardness(0.3);
--  Body.set_actuator_command(Config.stance.initangle)
end

--TODO: enable new nao specific
newnao = false; --Turn this on for new naos (run main code outside naoqi)
newnao = true;

getch.enableblock(1);
unix.usleep(1E6*1.0);
Body.set_body_hardness(0);

--This is robot specific
webots = false;
init = false;
calibrating = false;
ready = false;
if( webots or darwin) then
  ready = true;
end

initToggle = true;
targetvel=vector.zeros(3);
button_pressed = {0,0};
World.entry();
Vision.entry();

function process_keyinput()
  local str=getch.get();
  if #str>0 then
    local byte=string.byte(str,1);
    -- Walk velocity setting
    if byte==string.byte("i") then	targetvel[1]=targetvel[1]+0.02;
    elseif byte==string.byte("j") then	targetvel[3]=targetvel[3]+0.1;
    elseif byte==string.byte("k") then	targetvel[1],targetvel[2],targetvel[3]=0,0,0;
    elseif byte==string.byte("l") then	targetvel[3]=targetvel[3]-0.1;
    elseif byte==string.byte(",") then	targetvel[1]=targetvel[1]-0.02;
    elseif byte==string.byte("h") then	targetvel[2]=targetvel[2]+0.02;
    elseif byte==string.byte(";") then	targetvel[2]=targetvel[2]-0.02;

    elseif byte==string.byte("1") then
      kick.set_kick("kickForwardLeft");
      Motion.event("kick");
    elseif byte==string.byte("2") then
      kick.set_kick("kickForwardRight");
      Motion.event("kick");
    elseif byte==string.byte("3") then
      kick.set_kick("kickSideLeft");
      Motion.event("kick");
    elseif byte==string.byte("4") then
      kick.set_kick("kickSideRight");
      Motion.event("kick");
    elseif byte==string.byte("5") then
      walk.doWalkKickLeft();
    elseif byte==string.byte("6") then
      walk.doWalkKickRight();
    elseif byte==string.byte("t") then
      walk.doSideKickLeft();
    elseif byte==string.byte("y") then
      walk.doSideKickRight();


    elseif byte==string.byte("w") then
      Motion.event("diveready");
    elseif byte==string.byte("a") then
      dive.set_dive("diveLeft");
      Motion.event("dive");
    elseif byte==string.byte("s") then
      dive.set_dive("diveCenter");
      Motion.event("dive");
    elseif byte==string.byte("d") then
      dive.set_dive("diveRight");
      Motion.event("dive");

--[[
	elseif byte==string.byte("z") then
		grip.throw=0;
		Motion.event("pickup");
	elseif byte==string.byte("x") then
		grip.throw=1;
		Motion.event("throw");
--]]

	elseif byte==string.byte("z") then
	    walk.startMotion("hurray1");

	elseif byte==string.byte("x") then
	    walk.startMotion("hurray2");

	elseif byte==string.byte("c") then
	    walk.startMotion("swing");

	elseif byte==string.byte("v") then
	    walk.startMotion("2punch");

--	elseif byte==string.byte("b") then
--	    walk.startMotion("point");



	elseif byte==string.byte("b") then
	    grip.throw=0;
	    Motion.event("pickup");
	elseif byte==string.byte("n") then
	    grip.throw=1;
	    Motion.event("pickup");

    elseif byte==string.byte("7") then
      Motion.event("sit");
    elseif byte==string.byte("8") then
      if walk.active then walk.stop();end
      Motion.event("standup");
  --   headsm_running=0;
  --    Body.set_para_headpos(0.1,0);
  --    Body.set_state_headValid(1);
    elseif byte==string.byte("9") then
    --  Motion.event("walk");
    --  walk.start();
    end
    walk.set_velocity(unpack(targetvel));
    print("Command velocity:",unpack(walk.velCommand))
  end
end

-- main loop
count = 0;
lcount = 0;
tUpdate = unix.time();

function update()
  count = count + 1;
  if (not init)  then
    if (calibrating) then
      if (Body.calibrate(count)) then
        Speak.talk('Calibration done');
        calibrating = false;
        ready = true;
      end
    elseif (ready) then
      init = true;
    else
      if (count % 20 == 0) then
-- start calibrating w/o waiting
--        if (Body.get_change_state() == 1) then
          Speak.talk('Calibrating');
          calibrating = true;
--        end
      end
      -- toggle state indicator
      if (count % 100 == 0) then
        initToggle = not initToggle;
        if (initToggle) then
          Body.set_indicator_state({1,1,1});
        else
          Body.set_indicator_state({0,0,0});
        end
      end
    end
  else
    -- update state machines
    process_keyinput();
    Motion.update();
    Body.update();
    cognition.update();
---------------------------------------------------xpc test start-----------------------
--------------------------------------------------xpc test end---------------------------
--if walk.active then walk.stop(); end
		--bodysm_running=0;
		--	Motion.event("standup");
	      walk.start();
    if vcm.get_line_detect()==1 then
	local a = vcm.get_line_angle();

        if((a*180/math.pi)>90) then
	    b=a*180/math.pi-180;
            print("Find a line!!!!!!!!!!!!!!!!!!!!!!!,angle of the line is" ,b);
	else
	    print("Find a line!!!!!!!!!!!!!,angle of the line is",a*180/math.pi);
            b=a*180/math.pi;
	end
    end
    if vcm.get_line_detect()==1 then
	if (b>35) then
		print("I should trun left~~~~~~~~~~~~~~~~~");
		--walk.set_velocity(0.02,0.03,0.3);
		targetvel[1] = 0.02;
		targetvel[2] = 0.02;
		targetvel[3] = 0.1;
	elseif (b<-15) then
		print("I should turn Right~~~~~~~~~~~~~~~~~~");
		--walk.set_velocity(0.01,-0.03,-0.3);
		targetvel[1] = 0.02;
		targetvel[2] = -0.02;
		targetvel[3] = -0.1;
	else
		print("I should go straight!~~~~~~~~~~~~~~~");
		--walk.set_velocity(0.02,0,0);
		targetvel[1] = 0.02;
		targetvel[2] = 0.0;
		targetvel[3] = 0.0;
        end
    end
   -- Motion.event("walk");
   -- walk.start();
  end
	walk.set_velocity(unpack(targetvel));	--cancel for bodyfsm test

    Motion.update();
    Body.update();
  local dcount = 50;
  if (count % 50 == 0) then
--    print('fps: '..(50 / (unix.time() - tUpdate)));
    tUpdate = unix.time();
    -- update battery indicator
    Body.set_indicator_batteryLevel(Body.get_battery_level());
  end

  -- check if the last update completed without errors
  lcount = lcount + 1;
  if (count ~= lcount) then
    print('count: '..count)
    print('lcount: '..lcount)
    Speak.talk('missed cycle');
    lcount = count;
  end

  --Stop walking if button is pressed and the released
  if (Body.get_change_state() == 1) then
    button_pressed[1]=1;
  else
    if button_pressed[1]==1 then
      Motion.event("sit");
    end
    button_pressed[1]=0;
  end
end

-- if using Webots simulator just run update
if (webots) then
  while (true) do
    -- update motion process
    update();
    io.stdout:flush();
  end
end

--Now both nao and darwin runs this separately
if (darwin) or (newnao) then
  local tDelay = 0.005 * 1E6; -- Loop every 5ms
  while 1 do
    update();
    unix.usleep(tDelay);
  end
end
