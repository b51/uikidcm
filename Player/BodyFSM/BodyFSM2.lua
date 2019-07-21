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
local bodyDribble = require('bodyDribble')
local bodyKick = require('bodyKick')
local bodyWalkKick = require('bodyWalkKick')
local bodyOrbit = require('bodyOrbit')
local bodyGotoCenter = require('bodyGotoCenter')
local bodyPosition = require('bodyPosition')
local bodyObstacle = require('bodyObstacle')
local bodyObstacleAvoid = require('bodyObstacleAvoid')

local bodyPositionGoalie = require('bodyPositionGoalie')
local bodyAnticipate = require('bodyAnticipate')
local bodyChase = require('bodyChase')
local bodyDive = require('bodyDive')
local bodyReadyMove = require('bodyReadyMove')

local sm = {};
sm = fsm.new(bodyIdle);
sm:add_state(bodyStart);
sm:add_state(bodyStop);
sm:add_state(bodyReady);
sm:add_state(bodySearch);
sm:add_state(bodyApproach);
sm:add_state(bodyDribble);
sm:add_state(bodyKick);
sm:add_state(bodyWalkKick);
sm:add_state(bodyOrbit);
sm:add_state(bodyGotoCenter);
sm:add_state(bodyPosition);
sm:add_state(bodyObstacle);
sm:add_state(bodyObstacleAvoid);
sm:add_state(bodyDribble);

sm:add_state(bodyPositionGoalie);
sm:add_state(bodyAnticipate);
sm:add_state(bodyDive);
sm:add_state(bodyChase);

sm:add_state(bodyReadyMove);

------------------------------------------------------
-- Advanced FSM (bodyPosition)
------------------------------------------------------

sm:set_transition(bodyStart, 'done', bodyPosition);

sm:set_transition(bodyPosition, 'timeout', bodyPosition);
sm:set_transition(bodyPosition, 'ballLost', bodySearch);
sm:set_transition(bodyPosition, 'ballClose', bodyOrbit);
sm:set_transition(bodyPosition, 'obstacle', bodyObstacle);
sm:set_transition(bodyPosition, 'done', bodyApproach);
sm:set_transition(bodyPosition, 'dribble', bodyDribble);

sm:set_transition(bodyObstacle, 'clear', bodyPosition);
sm:set_transition(bodyObstacle, 'timeout', bodyObstacleAvoid);

sm:set_transition(bodyObstacleAvoid, 'clear', bodyPosition);
sm:set_transition(bodyObstacleAvoid, 'timeout', bodyPosition);

sm:set_transition(bodySearch, 'ball', bodyPosition);
sm:set_transition(bodySearch, 'timeout', bodyGotoCenter);

--sm:set_transition(bodySearch, 'ballgoalie', bodyChase);               --tse
--sm:set_transition(bodySearch, 'timeoutgoalie', bodyPositionGoalie);   --tse
sm:set_transition(bodySearch, 'ballgoalie', bodyPositionGoalie);      --tse
sm:set_transition(bodySearch, 'timeoutgoalie', bodySearch);   --tse

sm:set_transition(bodyGotoCenter, 'ballFound', bodyPosition);
sm:set_transition(bodyGotoCenter, 'done', bodySearch);
sm:set_transition(bodyGotoCenter, 'timeout', bodySearch);

sm:set_transition(bodyOrbit, 'timeout', bodyPosition);
sm:set_transition(bodyOrbit, 'ballLost', bodySearch);
sm:set_transition(bodyOrbit, 'ballFar', bodyPosition);
sm:set_transition(bodyOrbit, 'done', bodyApproach);

sm:set_transition(bodyApproach, 'ballFar', bodyPosition);
sm:set_transition(bodyApproach, 'ballLost', bodySearch);
sm:set_transition(bodyApproach, 'timeout', bodyPosition);
sm:set_transition(bodyApproach, 'kick', bodyKick);
sm:set_transition(bodyApproach, 'walkkick', bodyWalkKick);

sm:set_transition(bodyDribble, 'ballFar', bodyPosition);
sm:set_transition(bodyDribble, 'ballLost', bodySearch);
sm:set_transition(bodyDribble, 'timeout', bodyPosition);
sm:set_transition(bodyDribble, 'done', bodyPosition);

sm:set_transition(bodyKick, 'done', bodyPosition);
sm:set_transition(bodyKick, 'timeout', bodyPosition);
sm:set_transition(bodyKick, 'reposition', bodyApproach);
sm:set_transition(bodyWalkKick, 'done', bodyPosition);

sm:set_transition(bodyReady, 'done', bodyReadyMove);
sm:set_transition(bodyReadyMove, 'fall', bodyReadyMove);

sm:set_transition(bodyPosition, 'fall', bodyPosition);
sm:set_transition(bodyDribble, 'fall', bodyPosition);
sm:set_transition(bodyApproach, 'fall', bodyPosition);
sm:set_transition(bodyKick, 'fall', bodyPosition);

--Escape transitions for goalie
sm:set_transition(bodyStart, 'goalie', bodyAnticipate);
sm:set_transition(bodyPosition, 'goalie', bodyPositionGoalie);
--sm:set_transition(bodySearch, 'goalie', bodyPositionGoalie);    --tse

sm:set_transition(bodyPositionGoalie, 'player', bodyPosition);
sm:set_transition(bodyAnticipate,'player',bodyPosition);

--Goalie States

sm:set_transition(bodyPositionGoalie, 'ready', bodyAnticipate);
sm:set_transition(bodyPositionGoalie, 'ballClose', bodyChase);
sm:set_transition(bodyPositionGoalie, 'done', bodyAnticipate);     --tse

-- Timeout should stay in position, not start moving again
sm:set_transition(bodyAnticipate,'timeout',bodyAnticipate);
-- Change the ball if it is close enough, since a shot will go in anyway...
sm:set_transition(bodyAnticipate,'ballClose',bodyChase);
-- Add a dive when a shot is detected
sm:set_transition( bodyAnticipate,'dive',bodyDive );
-- If out of position, then position self again
--sm:set_transition(bodyAnticipate,'position',bodyPositionGoalie);    --tse

-- There is no 'done' event for anticipation
--sm:set_transition(bodyAnticipate,'done',bodyPositionGoalie);

--sm:set_transition(bodyChase, 'ballLost', bodyPositionGoalie);    --tse
--sm:set_transition(bodyChase, 'ballFar', bodyPositionGoalie);     --tse
sm:set_transition(bodyChase, 'ballClose', bodyApproach);
sm:set_transition(bodyChase, 'ballLost', bodySearch);      --tse
sm:set_transition(bodyChase, 'ballFar', bodySearch);       --tse

-- Chase after the ball if you make a save
--sm:set_transition(bodyDive, 'done', bodyChase);
-- Should timeout in case the fall is not detected...

--sm:set_transition(bodyDive, 'timeout', bodyPositionGoalie);
sm:set_transition(bodyDive, 'timeout', bodySearch);
sm:set_transition(bodyDive, 'reanticipate', bodyAnticipate);

--The transition after a dive should just come from a fall (or timeout in case)

sm:set_transition(bodyPositionGoalie, 'fall', bodyPositionGoalie);
sm:set_transition(bodyApproach, 'fall', bodyPositionGoalie);
--sm:set_transition(bodyChase, 'fall', bodyPositionGoalie);    --tse
sm:set_transition(bodyChase, 'fall', bodySearch);    --tse
sm:set_transition(bodyKick, 'fall', bodyPositionGoalie);
-- Chase the ball after a fall, since this could have been caused by a dive
sm:set_transition(bodyDive, 'fall', bodyChase);

-- set state debug handle to shared memory settor
sm:set_state_debug_handle(gcm.set_fsm_body_state);

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
  sm = sm,
};
