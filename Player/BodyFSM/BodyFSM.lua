local gcm = require('gcm')
local Config = require('Config')

--if Config.game.role==0 then
if Config.fsm.playMode==1 then
  -- Demo FSM (No orbit)
  print("====Demo FSM Loaded====")
  return require('BodyFSMDemo');
elseif Config.fsm.playMode==2 then
  -- Simple FSM (Approach and orbit)
  print("====Simple FSM Loaded====")
  return require('BodyFSM1');
elseif Config.fsm.playMode==3 then
  -- Advanced FSM
  print("====Advanced FSM Loaded====")
  return require('BodyFSM2');
elseif Config.fsm.playMode == 4 then
	print("====Passing Ball====")
	return require('BodyFSMPB');
end
