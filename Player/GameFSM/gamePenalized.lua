local _NAME = "gamePenalized";

local HeadFSM = require('HeadFSM')
local BodyFSM = require('BodyFSM')
local vector = require('vector')
local util = require('util')
local gcm = require('gcm')

local entry = function()
  print('GameFSM: '.._NAME..' entry');

  HeadFSM.sm:set_state('headIdle');
  BodyFSM.sm:set_state('bodyIdle');

  -- set indicator
  Body.set_indicator_state({1,0,0});
end

local update = function()
  local state = gcm.get_game_state();
  -- check for penalty
  if not gcm.in_penalty() then
    if (state == 0) then
      return 'initial';
    elseif (state == 1) then
      return 'ready';
    elseif (state == 2) then
      return 'set';
    elseif (state == 3) then
      return 'playing';
    elseif (state == 4) then
      return 'finished';
    end
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
