local Config = require('Config')
-- TODO(b51): Rename HeadFSM to more accurancy name instead of
--            number 1, 2. eg: HeadFSM1 -> HeadFSMGame, and fix
--            Config playMode = a table with strings,
--            eg: fsm.playMode = {Demo, Game, ...}

if Config.fsm.playMode==1 then
  print("====Demo HeadFSM loaded====")
  return require('HeadFSMDemo');
else
  print("====Player HeadFSM loaded====")
  return require('HeadFSM1');
end
