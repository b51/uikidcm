--SJ: IK based lookGoal to take account of bodytilt
local _NAME = "headLookGoal";

local Body = require('Body')
local Config = require('Config')
local vcm = require('vcm')

local t0_ = 0;
local yawSweep_ = Config.fsm.headLookGoal.yawSweep;
local yawMax_ = Config.head.yawMax;
local dist_ = Config.fsm.headReady.dist;
local tScan_ = Config.fsm.headLookGoal.tScan;
local minDist_ = Config.fsm.headLookGoal.minDist;
local yaw0_;

local entry = function()
  print("HeadFSM: ".._NAME.." entry");
  t0_ = Body.get_time();
  local attackAngle = wcm.get_attack_angle();
  local defendAngle = wcm.get_defend_angle();
  local attackClosest = math.abs(attackAngle) < math.abs(defendAngle);
  if attackClosest then
    yaw0_ = wcm.get_attack_angle();
  else
    yaw0_ = wcm.get_defend_angle();
  end
end

local update = function()
  local t = Body.get_time();
  local tpassed=t-t0_;
  local ph= tpassed/tScan_;
  local yawbias = (ph-0.5)* yawSweep_;

  local height=vcm.get_camera_height();

  local yaw1 = math.min(math.max(yaw0_+yawbias, -yawMax_), yawMax_);
  local yaw, pitch = HeadTransform.ikineCam(dist_ * math.cos(yaw1),
                                            dist_ * math.sin(yaw1),
                                            height);
  Body.set_head_command({yaw, pitch});
  pitch = pitch + 10*math.pi/180;

  Body.set_para_headpos(vector.new({yaw, pitch}));--123456î^²¿
  Body.set_state_headValid(1);--123456î^²¿

  local ball = wcm.get_ball();
  local ballR = math.sqrt (ball.x^2 + ball.y^2);

  if (t - t0_ > tScan_) then
    local tGoal = wcm.get_goal_t();
    if (tGoal - t0_ > 0) or ballR < minDist_ then
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
