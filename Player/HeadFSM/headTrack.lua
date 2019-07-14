module(..., package.seeall);

require('Body')
require('HeadTransform')
require('Config')
require('wcm')

t0 = 0;

minDist = Config.fsm.headTrack.minDist;
fixTh = Config.fsm.headTrack.fixTh;
trackZ = Config.vision.ball_diameter;
timeout = Config.fsm.headTrack.timeout;
tLost = Config.fsm.headTrack.tLost;

goalie_dive = Config.goalie_dive or 0;
goalie_type = Config.fsm.goalie_type;

deltaAngles = vector.zeros(2);
headAngleCal = vector.zeros(2);
lastDeltaAngles = vector.zeros(2);
lastHeadAngles = vector.zeros(2);
deltaYawCal = 0;
Kp = 0.5;
Kd = 0.3;

function entry()
  print("Head SM:".._NAME.." entry");

  t0 = Body.get_time();
end

function update()

  role = gcm.get_team_role();
  --Force attacker for demo code
  if Config.fsm.playMode==1 then role=1; end
  if role==0 and goalie_type>2 then --Escape if diving goalie
    return "goalie";
  end

  local t = Body.get_time();

  -- update head position based on ball location
  ball = wcm.get_ball();
  ballR = math.sqrt (ball.x^2 + ball.y^2);

  local yaw, pitch =
	HeadTransform.ikineCam(ball.x, ball.y, trackZ, bottom);

--	print("yaw,pitch :"..yaw,pitch);
--	print("ball.x,ball.y :"..ball.x,ball.y);

  -- Fix head yaw while approaching (to reduce position error)
--  if ball.x<fixTh[1] and math.abs(ball.y) < fixTh[2] then
--        yaw=0.0;
--  end

--b51: From Mos
  lastHeadAngles = {Body.get_sensor_headpos()[2],Body.get_sensor_headpos()[1]};
  deltaAngles[1] = yaw - lastHeadAngles[1];
  deltaAngles[2] = pitch - lastHeadAngles[2];
  headAngleCal[1] = lastHeadAngles[1] + Kp*deltaAngles[1] + Kd*(deltaAngles[1] - lastDeltaAngles[1]);
  headAngleCal[2] = lastHeadAngles[2] + Kp*deltaAngles[2] + Kd*(deltaAngles[2] - lastDeltaAngles[2]);
  deltaYawCal = headAngleCal[1] - lastHeadAngles[1];

  if (headAngleCal[2]>=(60*math.pi/180)) then
	  if (headAngleCal[2]>(67*math.pi/180)) then
		  pitch = 78*math.pi/180;
	  end

	  if (deltaYawCal > (45*math.pi/180)) then
		  yaw = lastHeadAngles[1] + 45*math.pi/180;
	  elseif (deltaYawCal < (-45*math.pi/180)) then
		  yaw = lastHeadAngles[1] - 45*math.pi/180;
	  else
		  yaw = lastHeadAngles[1];
	  end
  elseif headAngleCal[2]<0 then
	  pitch = 0;
  end
  lastDeltaAngles = deltaAngles;
  yaw = math.min((math.pi/2),math.max((-math.pi/2),yaw));

  Body.set_head_command({yaw, pitch});

  Body.set_para_headpos(vector.new({yaw, pitch}));--123456î^²¿
  Body.set_state_headValid(1);--123456î^²¿

  if (t - ball.t > tLost) then
    print('Ball lost!');
    return "lost";
  end
--TODO: generalize this using eta information
  if (t - t0 > timeout) and
     ballR > minDist   then
     if role==0 then
       return "sweep"; --Goalie, sweep to localize
     else
       return "timeout";  --Player, look up to see goalpost
     end
  end
end

function exit()
end
