module(..., package.seeall);

require('Body')
require('walk')
require('vector')
require('getch')
require('wcm')
require('gcm')


t0 = 0;
timeout = 3.0;
getch.enableblock(1);

function entry()
  print(_NAME.." entry");

  t0 = Body.get_time();
  walk.set_velocity(0,0,0);
  walk.stop();
  Speak.talk('Defending');
end

function update()
  local t = Body.get_time();
  walk.stop();
  local str=getch.get();
  if #str>0 then
    local byte=string.byte(str,1);
    if byte==string.byte("p") then
		return("done");
    elseif byte == string.byte("a") then
		return("go");
    end
  end
end

function exit()
  walk.start();
end
