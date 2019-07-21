local fsm = require('fsm')
local gcm = require('gcm')

local gameInitial = require('gameInitial')
local gameReady = require('gameReady')
local gameSet = require('gameSet')
local gamePlaying = require('gamePlaying')
local gamePenalized = require('gamePenalized')
local gameFinished = require('gameFinished')

local sm = {};
sm = fsm.new(gameInitial);
sm:add_state(gameReady);
sm:add_state(gameSet);
sm:add_state(gamePlaying);
sm:add_state(gamePenalized);
sm:add_state(gameFinished);

sm:set_transition(gameInitial, "ready", gameReady);
sm:set_transition(gameInitial, "set", gameSet);
sm:set_transition(gameInitial, "playing", gamePlaying);
sm:set_transition(gameInitial, "finished", gameFinished);

sm:set_transition(gameReady, "initial", gameInitial);
sm:set_transition(gameReady, "set", gameSet);
sm:set_transition(gameReady, "playing", gamePlaying);
sm:set_transition(gameReady, "finished", gameFinished);
sm:set_transition(gameReady, "penalized", gamePenalized);

sm:set_transition(gameSet, "initial", gameInitial);
sm:set_transition(gameSet, "ready", gameReady);
sm:set_transition(gameSet, "playing", gamePlaying);
sm:set_transition(gameSet, "finished", gameFinished);
sm:set_transition(gameSet, "penalized", gamePenalized);

sm:set_transition(gamePlaying, "initial", gameInitial);
sm:set_transition(gamePlaying, "ready", gameReady);
sm:set_transition(gamePlaying, "set", gameSet);
sm:set_transition(gamePlaying, "finished", gameFinished);
sm:set_transition(gamePlaying, "penalized", gamePenalized);

sm:set_transition(gamePenalized, "initial", gameInitial);
sm:set_transition(gamePenalized, "ready", gameReady);
sm:set_transition(gamePenalized, "set", gameSet);
sm:set_transition(gamePenalized, "playing", gamePlaying);

sm:set_transition(gameFinished, "initial", gameInitial);
sm:set_transition(gameFinished, "ready", gameReady);
sm:set_transition(gameFinished, "set", gameSet);
sm:set_transition(gameFinished, "playing", gamePlaying);

-- set state debug handle to shared memory settor
sm:set_state_debug_handle(gcm.set_fsm_game_state);

local entry = function()
  sm:entry()
end

local update = function()
  sm:update();
end

local exit = function()
  sm:exit();
end

return {
  entry = entry,
  update = update,
  exit = exit,
};
