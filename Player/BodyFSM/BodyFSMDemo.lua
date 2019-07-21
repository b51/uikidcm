local Body = require('Body')
local fsm = require('fsm')
local gcm = require('gcm')
local Config = require('Config')

local bodyIdle = require('bodyIdle')
local bodyStart = require('bodyStart')
local bodyStop = require('bodyStop')
local bodyReady = require('bodyReady')
local bodySearch = require('bodySearch')
local bodyApproach = require('bodyApproach')
local bodyKick = require('bodyKick')
local bodyWalkKick = require('bodyWalkKick')
local bodyOrbit = require('bodyOrbit')
local bodyGotoCenter = require('bodyGotoCenter')
local bodyPosition = require('bodyPosition')
local bodyObstacle = require('bodyObstacle')
local bodyObstacleAvoid = require('bodyObstacleAvoid')
local bodyDribble = require('bodyDribble')

local sm = {};
sm = fsm.new(bodyIdle);
sm:add_state(bodyStart);
sm:add_state(bodyStop);
sm:add_state(bodyReady);
sm:add_state(bodySearch);
sm:add_state(bodyApproach);
sm:add_state(bodyKick);
sm:add_state(bodyWalkKick);
sm:add_state(bodyOrbit);
sm:add_state(bodyGotoCenter);
sm:add_state(bodyPosition);
sm:add_state(bodyObstacle);
sm:add_state(bodyObstacleAvoid);
sm:add_state(bodyDribble);

------------------------------------------------------
-- Demo FSM (No orbit)
------------------------------------------------------

sm:set_transition(bodyStart, 'done', bodyPosition);

sm:set_transition(bodyPosition, 'timeout', bodyPosition);
sm:set_transition(bodyPosition, 'ballLost', bodySearch);
sm:set_transition(bodyPosition, 'ballClose', bodyApproach);
sm:set_transition(bodyPosition, 'obstacle', bodyObstacle);
sm:set_transition(bodyPosition, 'done', bodyApproach);
sm:set_transition(bodyPosition, 'dribble', bodyDribble);

sm:set_transition(bodyObstacle, 'clear', bodyPosition);
sm:set_transition(bodyObstacle, 'timeout', bodyObstacleAvoid);

sm:set_transition(bodyObstacleAvoid, 'clear', bodyPosition);
sm:set_transition(bodyObstacleAvoid, 'timeout', bodyPosition);

sm:set_transition(bodySearch, 'ball', bodyPosition);
sm:set_transition(bodySearch, 'timeout', bodyGotoCenter);

sm:set_transition(bodyGotoCenter, 'ballFound', bodyPosition);
sm:set_transition(bodyGotoCenter, 'done', bodySearch);
sm:set_transition(bodyGotoCenter, 'timeout', bodySearch);

sm:set_transition(bodyApproach, 'ballFar', bodyPosition);
sm:set_transition(bodyApproach, 'ballLost', bodySearch);
sm:set_transition(bodyApproach, 'timeout', bodyPosition);
sm:set_transition(bodyApproach, 'kick', bodyKick);
sm:set_transition(bodyApproach, 'walkkick', bodyWalkKick);

sm:set_transition(bodyKick, 'done', bodyPosition);
sm:set_transition(bodyKick, 'timeout', bodyPosition);
sm:set_transition(bodyKick, 'reposition', bodyApproach);
sm:set_transition(bodyWalkKick, 'done', bodyPosition);

sm:set_transition(bodyPosition, 'fall', bodyPosition);
sm:set_transition(bodyApproach, 'fall', bodyPosition);
sm:set_transition(bodyKick, 'fall', bodyPosition);

-- set state debug handle to shared memory settor
sm:set_state_debug_handle(gcm.set_fsm_body_state);

local entry = function()
  sm:entry()
  wcm.set_kick_dir(1);
  wcm.set_kick_type(2);
  wcm.set_kick_angle(0);
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
  sm = sm,
};
