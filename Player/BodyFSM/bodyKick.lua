local _NAME = "bodyKick";
local Body = require('Body')
local wcm = require('wcm')
local vector = require('vector')
local kick = require('kick');
local Config = require('Config')
local Motion = require('Motion');
local HeadFSM = require('HeadFSM')
local walk = require('walk');

--initial wait
local tStartWait = Config.fsm.bodyKick.tStartWait or 0.5;
local tStartWaitMax = Config.fsm.bodyKick.tStartWaitMax or 1.0;
local thGyroMag = Config.fsm.bodyKick.thGyroMag or 100;

--ball position checking params
local kickTargetFront=Config.fsm.bodyKick.kickTargetFront or {0.15,0.04};
local kickTargetSide=Config.fsm.bodyKick.kickTargetSide or {0.15,0.04};
local kickTh=Config.fsm.bodyKick.kickTh or {0.03,0.025};

--headFollow delay
local tFollowDelay = Config.fsm.bodyKick.tFollowDelay;

local t0 = 0;
local tStart = 0;
local timeout = 10.0;
local phase=0; --0 for init.wait, 1 for kicking, 2 for headFollow
local kickable = true;

local check_ball_pos = function()
  local ball = wcm.get_ball();

  local kick_dir=wcm.get_kick_dir();
  if kick_dir==1 then
    print("do kick, ball position :",ball.x, ball.y);
    print("ball.y > 0, kick left ,ball.y < 0, kick right:",ball.y);
    -- straight kick, set kick depending on ball position
    if (ball.y > 0) then
      kick.set_kick("kickForwardLeft");
      xTarget,yTarget=kickTargetFront[1],kickTargetFront[2];
    else
      kick.set_kick("kickForwardRight");
      xTarget,yTarget=kickTargetFront[1],-kickTargetFront[2];
    end
  elseif kick_dir==2 then --Kick to left
    kick.set_kick("kickSideRight");
    xTarget,yTarget=kickTargetSide[1],kickTargetSide[2];
  else --Kick to right
    kick.set_kick("kickSideLeft");
    xTarget,yTarget=kickTargetSide[1],-kickTargetSide[2];
  end
  print("Kick dir:",kick_dir)
  print("Ball position: ",ball.x,ball.y)
  print("Ball target:",xTarget,yTarget)

  local ballErr = {ball.x-xTarget,ball.y-yTarget};
  print("ball error:",table.unpack(ballErr))
  print("Ball pos threshold:",table.unpack(kickTh))
  print("Ball seen:",t-ball.t," sec ago");

  if ballErr[1]<kickTh[1] and --We don't care if ball is too close
      math.abs(ballErr[2])<kickTh[2] and
    (t - ball.t <0.5) then
    return true;
  else
    return false;
  end
end


local entry = function()
  print("BodyFSM: ".._NAME.." entry");
  t0 = Body.get_time();
  --SJ - only initiate kick while walking
  kickable = walk.active;
  walk.stop();
  phase=0;
end

local update = function()
  local t = Body.get_time();
  if not kickable then
     print("bodyKick escape");
     --Set velocity to 0 after kick fails ot prevent instability--
     walk.set_velocity(0, 0, 0);
     return "done";
  end

  if (t - t0 > timeout) then
    print("bodyKick timeout")
    return "timeout";
  end

  --wait until vibration ceases
  -- TODO(b51): Should check bodyKick carefully, cause our robots
  --            do kick few
  if phase==0 and not walk.active then
    local tPassed=t-t0;
    local imuGyr = Body.get_sensor_imuGyrRPY();
    local gyrMag = math.sqrt(imuGyr[1]^2+imuGyr[2]^2);

    if tPassed>tStartWaitMax or
        (tPassed>tStartWait and gyrMag<thGyroMag) then
      if check_ball_pos() then
        phase=1;
        tStart=t;
        Motion.event("kick");
      else
        print("bodyKick: reposition")
        walk.start();
        return "reposition";
      end
    end
  elseif phase==1 then
  --Wait a bit and try find the ball
    if t-tStart > tFollowDelay then
      phase=2;
      HeadFSM.sm:set_state('headKickFollow');
    end
  elseif phase==2 then
  --Wait until kick is over
    if not kick.active then
      walk.still=true;
      walk.set_velocity(0, 0, 0);
      walk.start();
      return "done";
    end
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
