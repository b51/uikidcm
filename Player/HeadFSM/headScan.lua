local _NAME = "headScan";

local Body = require('Body')
local Config = require('Config')
local wcm = require('wcm')
local mcm = require('mcm')

local pitch0_ = Config.fsm.headScan.pitch0;
local pitchMag_ = Config.fsm.headScan.pitchMag;
local yawMag_ = Config.fsm.headScan.yawMag;
local yawMagTurn_ = Config.fsm.headScan.yawMagTurn;

local pitchTurn0_ = Config.fsm.headScan.pitchTurn0;
local pitchTurnMag_ = Config.fsm.headScan.pitchTurnMag;

local tScan_ = Config.fsm.headScan.tScan;
local timeout_ = tScan_ * 2;

local t0_ = 0;
local direction_ = 1;
local count_ = 0;	--168
local pitchDir_ = 1;

local entry = function()
  print("HeadFSM: ".._NAME.." entry");
  --Goalie need wider scan
  local role = gcm.get_team_role();
  if role == 0 then
    yawMag_ = Config.fsm.headScan.yawMagGoalie;
  else
    yawMag_ = Config.fsm.headScan.yawMag_;
  end

  -- start scan in ball's last known direction
  t0_ = Body.get_time();
  local ball = wcm.get_ball();
  timeout_ = tScan_ * 2;

  local yaw_0, pitch_0 = HeadTransform.ikineCam(ball.x, ball.y,0);
  --local currentYaw = Body.get_sensor_headpos()[1];--123456
  local currentYaw = Body.get_sensor_headpos()[2];	--b51

  if currentYaw > 0 then
    direction_ = 1;
  else
    direction_ = -1;
  end
  if pitch_0 > pitch0_ then
    pitchDir_ = 1;
  else
    pitchDir_ = -1;
  end
end

local update = function()
  local pitchBias =  mcm.get_headPitchBias();--Robot specific head angle bias
  --Is the robot in bodySearch and spinning?
  local isSearching = mcm.get_walk_isSearching();

  local t = Body.get_time();
  -- update head position

  -- Scan left-right and up-down with constant speed
  if isSearching == 0 then --Normal headScan
    local ph = (t-t0_)/tScan_;
    ph = ph - math.floor(ph);

    local yaw, pitch;
    if ph<0.25 then --phase 0 to 0.25
      yaw = yawMag_*(ph*4)* direction_;
      pitch = pitch0_+pitchMag_*pitchDir_;
    elseif ph<0.75 then --phase 0.25 to 0.75
      yaw = yawMag_*(1-(ph-0.25)*4)* direction_;
      pitch = pitch0_-pitchMag_*pitchDir_;
    else --phase 0.75 to 1
      yaw = yawMag_*(-1+(ph-0.75)*4)* direction_;
--      pitch=pitch0_+pitchMag_*pitchDir_;
--      pitch=pitch0_*pitchDir_;
      pitch = pitch0_;
    end
  else --Rotating scan
    timeout_ = 20.0 * Config.speedFactor; --Longer timeout
    local ph = (t-t0_)/tScan_ * 1.5;
    ph = ph - math.floor(ph);
    --Look up and down in constant speed
    if ph<0.25 then
      pitch = pitchTurn0_+pitchTurnMag_*(ph*4);
      yaw = yawMag_*(ph*4)* direction_;
    elseif ph<0.75 then
--      pitch=pitchTurn0_+pitchTurnMag_*(1-(ph-0.25)*4);
      pitch = pitchTurn0_-pitchTurnMag_*(1-(ph-0.25)*4);
      yaw = yawMag_*(1-(ph-0.25)*4)* direction_;
    else
      pitch = pitchTurn0_+pitchTurnMag_*(-1+(ph-0.75)*4);
      yaw = yawMag_*(-1+(ph-0.75)*4)* direction_;
    end
    --yaw = yawMagTurn_ * isSearching;
  end
  Body.set_head_command({yaw, pitch-pitchBias});
  Body.set_para_headpos(vector.new({yaw, pitch-pitchBias}));--123456
  Body.set_state_headValid(1);--123456

  local ball = wcm.get_ball();
  if (t - ball.t < 0.1) then
    return "ball";
  end
  if (t - t0_ > timeout_) then
    return "timeout";
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
