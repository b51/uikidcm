local _NAME = "gamePlaying";

local Body = require('Body')
local walk = require('walk')
local BodyFSM = require('BodyFSM')
local HeadFSM = require('HeadFSM')
local vector = require('vector')
local gcm = require('gcm')

local t0_ = 0;

local entry = function()
  print('GameFSM: '.._NAME..' entry');

  t0_ = Body.get_time();

  BodyFSM.sm:set_state('bodyStart');
  HeadFSM.sm:set_state('headStart');

  -- set indicator
  Body.set_indicator_state({0,1,0});
end

local update = function()
  local state = gcm.get_game_state();

  if (state == 0) then
    return 'initial';
  elseif (state == 1) then
    return 'ready';
  elseif (state == 2) then
    return 'set';
  elseif (state == 4) then
    return 'finished';
  end

  -- check for penalty
  if gcm.in_penalty() then
    return 'penalized';
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
