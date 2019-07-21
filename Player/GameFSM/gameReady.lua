local _NAME = "gameReady";

local Body = require('Body')
local walk = require('walk')
local vector = require('vector')
local gcm = require('gcm')
local BodyFSM = require('BodyFSM')
local HeadFSM = require('HeadFSM')

local t0_ = 0;
local timeout_ = 2.0;

local entry = function()
  print('GameFSM: '.._NAME..' entry');

  t0_ = Body.get_time();
  walk.start();

  -- body ready state
  BodyFSM.sm:set_state('bodyReady');
  HeadFSM.sm:set_state('headReady');

  -- set indicator
  Body.set_indicator_state({0,0,1});
end

local update = function()
  local state = gcm.get_game_state();

  if (state == 0) then
    return 'initial';
  elseif (state == 2) then
    return 'set';
  elseif (state == 3) then
    return 'playing';
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
