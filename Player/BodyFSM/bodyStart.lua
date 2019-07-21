local _NAME = "bodyStart";
local Body = require('Body')
local walk = require('walk')
local gcm = require('gcm')
local wcm = require('wcm')
local Config = require('Config')

local t0=0;
local tLastCount=0;

local tKickOff=10.0; --5 sec max wait before moving
--If ball moves more than this amount, start moving
local ballTh = 0.50;
--If the ball comes any closer than this, start moving
local ballClose = 0.50;

local wait_kickoff = Config.fsm.wait_kickoff or 0;
local kickoff = 0;
local ball0 = 10;

if Config.fsm.playMode == 1 then
  --Turn off kickoff waiting for demo
  wait_kickoff = 0;
end

local entry = function()
  print("BodyFSM: ".._NAME.." entry");
  --Kickoff handling (only for attacker)
  --TODO: This flag is set when player returns from penalization too
  if gcm.get_team_role()<4 and wait_kickoff>0 then
    if gcm.get_game_kickoff()==1 then
      --Our kickoff, go ahead and kick the ball
      --Kickoff kick should be different
      wcm.set_kick_kickOff(1);
      wcm.set_kick_tKickOff(Body.get_time());
    else
      --Their kickoff, wait for ball moving
      print("Waiting for opponent's kickoff");
      kickoff=1;
      t0=Body.get_time();
      tLastCount=t0;
      ball0 = wcm.get_ball();
      walk.stop();
    end
  else
    kickoff=0; --Defenders may move
  end
end

local update = function()
  local role = gcm.get_team_role();
  if role==0 then
    return 'goalie'
  end

  local t=Body.get_time();
  if kickoff>0 then
    walk.stop();
    local ball = wcm.get_ball();
    local ballDiff={ball.x-ball0.x,ball.y-ball0.y};
    if math.sqrt(ballDiff[1]^2+ballDiff[2]^2)>ballTh or
       math.sqrt(ball.x^2+ball.y^2)<ballClose then
       return 'done';
    else
      role = gcm.get_team_role();
      if role==1 then
        tKickOff=10.0;
      else
        tKickOff=7.0;
      end

      local tRemaining = tKickOff-(t-t0);
      if tRemaining<0 then
        return 'done';
      elseif t>tLastCount then
        tLastCount=tLastCount+1;
        local countdown=string.format("%d",tRemaining)
        print("Count: ",countdown)
      end
    end
  else
    return 'done';
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
