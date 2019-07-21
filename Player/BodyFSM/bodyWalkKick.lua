-- Test SM for walk kick
-- Not for distribute
local _NAME = "bodyWalkKick";
local Body = require('Body')
local wcm = require('wcm')
local vector = require('vector')
local Config = require('Config')
local HeadFSM = require('HeadFSM')
local Motion = require('Motion');
local kick = require('kick');
local walk = require('walk');

local t0 = 0;
local timeout = Config.fsm.bodyWalkKick.timeout;

local walkkick_th = 0.14; --Threshold for step-back walkkick for OP
local follow = false;

local entry = function()
  print("BodyFSM: ".._NAME.." entry");
  t0 = Body.get_time();
  follow=false;
  local kick_dir=wcm.get_kick_dir();

  -- if kick_dir==1 then --straight walkkick
  -- set kick depending on ball position
  local ball = wcm.get_ball();
  if (ball.y > 0) then
    if (ball.x>walkkick_th) or Config.fsm.enable_walkkick<2 then
      walk.doWalkKickLeft();
    else
      walk.doWalkKickLeft2();
    end
  else
    if (ball.x>walkkick_th) or Config.fsm.enable_walkkick<2 then
      walk.doWalkKickRight();
    else
      walk.doWalkKickRight2();
    end
  end
--  elseif kick_dir==2 then --sidekick to left
--    walk.doSideKickLeft();
--  else
--    walk.doSideKickRight(); --sidekick to right
--  end
  HeadFSM.sm:set_state('headTrack');
--  HeadFSM.sm:set_state('headIdle');
end

local update = function()
  local t = Body.get_time();

  if (t - t0 > timeout) then
    return "done";
  end

  --SJ: should be done in better way?
  if walk.walkKickRequest==0 and follow ==false then
    follow=true;
    HeadFSM.sm:set_state('headKickFollow');
  end

end

local exit = function()
 -- HeadFSM.sm:set_state('headTrack');
end

return {
  _NAME = _NAME,
  entry = entry,
  update = update,
  exit = exit,
}
