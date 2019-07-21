local _NAME = "headTrack"

local Body = require('Body')
local vector = require('vector')
local HeadTransform = require('HeadTransform')
local Config = require('Config')
local wcm = require('wcm')

local t0_ = 0;

local minDist_ = Config.fsm.headTrack.minDist;
local fixTh_ = Config.fsm.headTrack.fixTh;
local trackZ_ = Config.vision.ball_diameter;
local timeout_ = Config.fsm.headTrack.timeout;
local tLost_ = Config.fsm.headTrack.tLost;

local goalie_dive_ = Config.goalie_dive or 0;
local goalie_type_ = Config.fsm.goalie_type;

local deltaAngles_ = vector.zeros(2);
local headAngleCal_ = vector.zeros(2);
local lastDeltaAngles_ = vector.zeros(2);
local lastHeadAngles_ = vector.zeros(2);
local Kp_ = 0.5;
local Kd_ = 0.3;

local entry = function()
  print("HeadFSM: ".._NAME.." entry");
  t0_ = Body.get_time();
end

local update = function()
  local role = gcm.get_team_role();
  --Force attacker for demo code
  if Config.fsm.playMode == 1 then
    role = 1;
  end
  if role == 0 and goalie_type > 2 then --Escape if diving goalie
    return "goalie";
  end

  local t = Body.get_time();

  -- update head position based on ball location
  local ball = wcm.get_ball();
  local ballR = math.sqrt (ball.x^2 + ball.y^2);

  local yaw, pitch =
	    HeadTransform.ikineCam(ball.x, ball.y, trackZ_, bottom);

--	print("yaw,pitch :"..yaw,pitch);
--	print("ball.x,ball.y :"..ball.x,ball.y);

  -- Fix head yaw while approaching (to reduce position error)
--  if ball.x<fixTh[1] and math.abs(ball.y) < fixTh[2] then
--        yaw=0.0;
--  end

--b51: From Mos
  lastHeadAngles_ = {Body.get_sensor_headpos()[2],
                     Body.get_sensor_headpos()[1]};
  deltaAngles_[1] = yaw - lastHeadAngles_[1];
  deltaAngles_[2] = pitch - lastHeadAngles_[2];
  headAngleCal_[1] = lastHeadAngles_[1] + Kp_ * deltaAngles_[1]
      + Kd_ * (deltaAngles_[1] - lastDeltaAngles_[1]);
  headAngleCal_[2] = lastHeadAngles_[2] + Kp_ * deltaAngles_[2]
      + Kd_ * (deltaAngles_[2] - lastDeltaAngles_[2]);
  local deltaYawCal = headAngleCal_[1] - lastHeadAngles_[1];

  if (headAngleCal_[2] >= (60*math.pi/180)) then
	    if (headAngleCal_[2] > (67*math.pi/180)) then
	      pitch = 78*math.pi/180;
	    end

	  if (deltaYawCal > (45*math.pi/180)) then
		  yaw = lastHeadAngles_[1] + 45*math.pi/180;
	  elseif (deltaYawCal < (-45*math.pi/180)) then
		  yaw = lastHeadAngles_[1] - 45*math.pi/180;
	  else
		  yaw = lastHeadAngles_[1];
	  end
  elseif headAngleCal_[2]<0 then
	  pitch = 0;
  end
  lastDeltaAngles_ = deltaAngles_;
  yaw = math.min((math.pi/2), math.max((-math.pi/2), yaw));

  Body.set_head_command({yaw, pitch});

  Body.set_para_headpos(vector.new({yaw, pitch}));--123456î^²¿
  Body.set_state_headValid(1);--123456î^²¿

  if (t - ball.t > tLost_) then
    print('Ball lost!');
    return "lost";
  end
  --TODO: generalize this using eta information
  if (t - t0_ > timeout_) and
     ballR > minDist_   then
     if role == 0 then
       return "sweep"; --Goalie, sweep to localize
     else
       return "timeout";  --Player, look up to see goalpost
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
