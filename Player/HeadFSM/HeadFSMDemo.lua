local Body = require('Body')
local fsm = require('fsm')
local gcm = require('gcm')

local headIdle = require('headIdle')
local headStart = require('headStart')
local headReady = require('headReady')
local headReadyLookGoal = require('headReadyLookGoal')
local headScan = require('headScan')
local headTrack = require('headTrack')
local headKick = require('headKick')
local headKickFollow = require('headKickFollow')
local headLookGoal = require('headLookGoal')
local headLog = require('headLog')
local headSweep = require('headSweep')

local sm = {};
sm = fsm.new(headIdle);
sm:add_state(headStart);
sm:add_state(headReady);
sm:add_state(headReadyLookGoal);
sm:add_state(headScan);
sm:add_state(headTrack);
sm:add_state(headKick);
sm:add_state(headLog);
sm:add_state(headKickFollow);
sm:add_state(headLookGoal);
sm:add_state(headSweep);

if Config.fsm.playMode==1 then
---------------------------------------------
--Demo FSM w/o looking at the goal
---------------------------------------------
  sm:set_transition(headStart, 'done', headTrack);
  
  sm:set_transition(headReady, 'done', headScan);
  
  sm:set_transition(headTrack, 'lost', headScan);
  sm:set_transition(headTrack, 'timeout', headTrack);
  
  sm:set_transition(headKick, 'ballFar', headTrack);
  sm:set_transition(headKick, 'ballLost', headScan);
  sm:set_transition(headKick, 'timeout', headTrack);
  
  sm:set_transition(headKickFollow, 'lost', headScan);
  sm:set_transition(headKickFollow, 'ball', headTrack);
  
  sm:set_transition(headScan, 'ball', headTrack);
  sm:set_transition(headScan, 'timeout', headScan);
else
---------------------------------------------
--Game FSM with looking at the goal
---------------------------------------------
  sm:set_transition(headStart, 'done', headTrack);
  
  sm:set_transition(headReady, 'done', headReadyLookGoal);
  
  sm:set_transition(headReadyLookGoal, 'timeout', headReady);
  sm:set_transition(headReadyLookGoal, 'lost', headReady);
  
  sm:set_transition(headTrack, 'lost', headScan);
  sm:set_transition(headTrack, 'timeout', headLookGoal);
  
  sm:set_transition(headKickFollow, 'lost', headScan);
  sm:set_transition(headKickFollow, 'ball', headTrack);
  
  sm:set_transition(headLookGoal, 'timeout', headTrack);
  sm:set_transition(headLookGoal, 'lost', headSweep);
  
  sm:set_transition(headSweep, 'done', headTrack);
  
  sm:set_transition(headScan, 'ball', headTrack);
  sm:set_transition(headScan, 'timeout', headScan);
end

-- set state debug handle to shared memory settor
sm:set_state_debug_handle(gcm.set_fsm_head_state);

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
