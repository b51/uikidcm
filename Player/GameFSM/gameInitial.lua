local _NAME = "gameInitial";

local Config = require('Config')
local Body = require('Body');
local walk = require('walk')
local BodyFSM = require('BodyFSM')
local HeadFSM = require('HeadFSM')
local vector = require('vector')
local unix = require('unix')
local gcm = require('gcm')

local t0_ = 0;
local timeout_ = 1.0;

local entry = function()
  print('GameFSM: '.._NAME..' entry');
  t0_ = Body.get_time();
  walk.stop();

  HeadFSM.sm:set_state('headIdle');
  BodyFSM.sm:set_state('bodyIdle');

  -- set indicator
  --Body.set_indicator_state({1,1,1});
end

local update = function()
  local state = gcm.get_game_state();

  if (state == 1) then
    return 'ready';
  elseif (state == 2) then
    return 'set';
  elseif (state == 3) then
    return 'playing';
  elseif (state == 4) then
    return 'finished';
  end

  -- if we have not recieved game control packets then left bumper switches team color
  if (unix.time() - gcm.get_game_last_update() > 10.0) then
    if (Body.get_change_team() == 1) then
      gcm.set_team_color(1 - gcm.get_team_color());
    end
    if (Body.get_change_kickoff() == 1) then
      gcm.set_game_kickoff(1 - gcm.get_game_kickoff());
    end
  end
end

local exit = function()
  walk.start();
end

return {
  _NAME = _NAME,
  entry = entry,
  update = update,
  exit = exit,
};
