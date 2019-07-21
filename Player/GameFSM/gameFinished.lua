local _NAME = "gameFinished";

local BodyFSM = require('BodyFSM')
local HeadFSM = require('HeadFSM')
local vector = require('vector')
local gcm = require('gcm')

local entry = function()
  print('GameFSM: '.._NAME..' entry');

  HeadFSM.sm:set_state('headIdle');
  BodyFSM.sm:set_state('bodyIdle');

  -- set indicator
  Body.set_indicator_state({0,0,0});
end

local update = function()
  local state = gcm.get_game_state();

  if (state == 0) then
    return 'initial';
  elseif (state == 1) then
    return 'ready';
  elseif (state == 2) then
    return 'set';
  elseif (state == 3) then
    return 'playing';
  end
end

local exit = function()
end

return {
  _NAME = _NAME,
  entry = entry,
  update = update,
  exit = exit,
};
