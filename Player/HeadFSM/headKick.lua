------------------------------
-- Fix the head angle during approaching
------------------------------
local _NAME = "headKick";

local Body = require('Body')
local Config = require('Config')
local wcm = require('wcm')
local mcm = require('mcm')
local HeadTransform = require('HeadTransform');

local t0_ = 0;

-- follow period
local timeout_ = Config.fsm.headKick.timeout;
local tLost_ = Config.fsm.headKick.tLost;
local pitch0_ = Config.fsm.headKick.pitch0;
local xMax_ = Config.fsm.headKick.xMax;
local yMax_ = Config.fsm.headKick.yMax;

local entry = function()
  print("HeadFSM: ".._NAME.." entry");
  t0_ = Body.get_time();
end

local update = function()
  local pitchBias =  mcm.get_headPitchBias();--robot specific head bias

  local t = Body.get_time();
  local ball = wcm.get_ball();

  if ball.x<xMax_ and math.abs(ball.y)<yMax_ then
    Body.set_head_command({0, pitch0_-pitchBias_});
    Body.set_para_headpos(vector.new({0, pitch0_-pitchBias_}));--123456頭部
    Body.set_state_headValid(1);--123456頭部
  else
    local yaw, pitch = HeadTransform.ikineCam(ball.x, ball.y, 0.03);
    --local currentYaw = Body.get_sensor_headpos()[1];--123456
    --local currentPitch = Body.get_sensor_headpos()[2];--123456
    local currentYaw = Body.get_sensor_headpos()[2];	--b51
    local currentPitch = Body.get_sensor_headpos()[1];	--b51
    local p = 0.3;
    yaw = currentYaw + p*(yaw - currentYaw);
    pitch = currentPitch + p*(pitch - currentPitch);
    Body.set_head_command({yaw, pitch});
    Body.set_para_headpos(vector.new({yaw, pitch}));--123456頭部
    Body.set_state_headValid(1);--123456頭部
  end

  if (t - ball.t > tLost_) then
    return "ballLost";
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
