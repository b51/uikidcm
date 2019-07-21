------------------------------
-- Follow the ball after kicking
------------------------------
local _NAME = "headKickFollow";

local Body = require('Body')
local Config = require('Config')
local wcm = require('wcm')
local mcm = require('mcm')

local t0_ = 0;

-- follow period
local tFollow_ = Config.fsm.headKickFollow.tFollow;
local pitch0_ = Config.fsm.headKickFollow.pitch[1];
local pitch1_ = Config.fsm.headKickFollow.pitch[2];
local pitchSide_ = Config.fsm.headKickFollow.pitchSide;
local yawMagSide_ = Config.fsm.headKickFollow.yawMagSide;
local kick_dir_ = 1;

local entry = function()
  print("HeadFSM: ".._NAME.." entry");
  t0_ = Body.get_time();
  kick_dir_ = wcm.get_kick_dir();
end

local update = function()
  local pitchBias =  mcm.get_headPitchBias();--robot specific head bias

  local t = Body.get_time();
  local ph = (t-t0_)/tFollow_;
  local pitch = 0;
  local yaw = 0;

  if kick_dir_ == 1 then --front kick
      pitch = (1-ph)*pitch0_ + ph*pitch1_;
      yaw=0;
  elseif kick_dir_==2 then --sidekick to the left
      pitch = (1-ph)*pitch0_ + ph*pitch1_;
      yaw = ph*yawMagSide_;
  else --sidekick to the right
      pitch = (1-ph)*pitch0_ + ph*pitch1_;
      yaw = ph*-yawMagSide_;
  end
  Body.set_head_command({yaw, pitch-pitchBias});
  Body.set_para_headpos(vector.new({yaw, pitch-pitchBias}));--123456î^²¿
  Body.set_state_headValid(1);--123456î^²¿

  local ball = wcm.get_ball();
  if (t - ball.t < 0.1) then
    print("BallFound")
    return "ball";
  end
  if (t - t0_ > tFollow_) then
    return "lost";
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
