local _NAME = "headLog";

local Body = require('Body')
local Config = require('Config')
local wcm = require('wcm')
local mcm = require('mcm')

local pitch0_, pitchMag_, yawMag_;

if Config.fsm.headLog then
  pitch0_ = Config.fsm.headLog.pitch0 or 20*math.pi/180;
  pitchMag_ = Config.fsm.headScan.pitchMag or 30*math.pi/180;
  yawMag_ = Config.fsm.headScan.yawMag or 90*math.pi/180;
else
  pitch0_ = 20*math.pi/180;
  pitchMag_ = 20*math.pi/180;
  yawMag_ = 90*math.pi/180;
end

local tScan_ = 10.0;
local timeout_ = tScan_ * 2;

local t0_ = 0;
local direction_ = 1;
local pitchDir_ = 1;

local entry = function()
  print("HeadFSM: ".._NAME.." entry");
  -- start scan in ball's last known direction
  t0_ = Body.get_time();
  local ball = wcm.get_ball();
  timeout_ = tScan_ * 2;

  local yaw_0, pitch_0 = HeadTransform.ikineCam(ball.x, ball.y,0);
  -- local currentYaw = Body.get_sensor_headpos()[1];--123456
  local currentYaw = Body.get_sensor_headpos()[2];	--b51
  if currentYaw>0 then
    direction_ = 1;
  else
    direction_ = -1;
  end
  if pitch_0>pitch0_ then
    pitchDir_=1;
  else
    pitchDir_=-1;
  end
end

local update = function()
  local pitchBias =  mcm.get_headPitchBias();--Robot specific head angle bias
  local t = Body.get_time();

  -- update head position
  local ph = (t-t0_)/tScan_;
  local yaw, pitch;

  ph = ph - math.floor(ph);
  if ph<0.25 then --phase 0 to 0.25
    yaw=yawMag_*(ph*4)* direction_;
    pitch=pitch0_+pitchMag_*pitchDir_;
  elseif ph<0.75 then --phase 0.25 to 0.75
    yaw=yawMag_*(1-(ph-0.25)*4)* direction_;
    pitch=pitch0_-pitchMag_*pitchDir_;
  else --phase 0.75 to 1
    yaw=yawMag_*(-1+(ph-0.75)*4)* direction_;
    pitch=pitch0_+pitchMag_*pitchDir_;
  end
--  Body.set_head_command({yaw, pitch-pitchBias});
  Body.set_para_headpos(vector.new({yaw, pitch-pitchBias}));--123456î^²¿
  Body.set_state_headValid(1);--123456î^²¿
end

local exit = function()
end

return {
  _NAME = _NAME,
  entry = entry,
  update = update,
  exit = exit,
};
