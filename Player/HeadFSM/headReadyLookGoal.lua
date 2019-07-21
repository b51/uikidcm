local _NAME = "headReadyLookGoal";

local Body = require('Body')
local vector = require('vector')
local HeadTransform = require('HeadTransform')
local Config = require('Config')
local vcm = require('vcm')
local wcm = require('wcm')

local t0_ = 0;

local yawMax_ = Config.head.yawMax;

local dist_ = Config.fsm.headReady.dist;
local height_ = Config.fsm.headReady.height;
local timeout_ = Config.fsm.headReadyLookGoal.timeout;
local attackClosest_;

local entry = function()
  print("HeadFSM: ".._NAME.." entry");

  t0_ = Body.get_time();

  local attackAngle = wcm.get_attack_angle();
  local defendAngle = wcm.get_defend_angle();
  attackClosest_ = math.abs(attackAngle) < math.abs(defendAngle);

  -- only use top camera
  vcm.set_camera_command(0);
end

function update()
  local t = Body.get_time();
  height_ = vcm.get_camera_height();

  local yaw0;
  if attackClosest_ then
    yaw0 = wcm.get_attack_angle();
  else
    yaw0 = wcm.get_defend_angle();
  end

  local yawbias = 0;
  local yaw1 = math.min(math.max(yaw0+yawbias, -yawMax_), yawMax_);
  local yaw, pitch = HeadTransform.ikineCam(dist_ * math.cos(yaw1),
                                            dist_ * math.sin(yaw1),
                                            height_);
  Body.set_head_command({yaw, pitch*180/math.pi});
  pitch = pitch + 10*math.pi/180
  Body.set_para_headpos(vector.new({yaw, pitch}));--123456î^²¿
  Body.set_state_headValid(1);--123456î^²¿

  if (t - t0_ > timeout_) then
    local tGoal = wcm.get_goal_t();
    if (tGoal - t0_ > 0) then
      return 'timeout';
    else
      return 'lost';
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
