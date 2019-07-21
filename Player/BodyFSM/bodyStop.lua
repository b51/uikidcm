local _NAME = "bodyStop";
local Body = require('Body')
local Motion = require('Motion')

local started = false;

local entry = function()
  print('BodyFSM: '.._NAME..' entry');
  walk.set_velocity(0,0,0);
  walk.stop();
  started = false;
end

local update = function()
  --for webots : we have to stop with 0 bodytilt
  if not started then
    if not walk.active then
    Motion.sm:set_state('standstill');
    started = true;
    end
  end

end

local exit = function()
  Motion.sm:add_event('walk');
end

return {
  _NAME = _NAME,
  entry = entry,
  update = update,
  exit = exit,
};
