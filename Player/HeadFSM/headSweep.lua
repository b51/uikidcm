--SJ: New headSweep using camera inverse kinematics
local _NAME = "headSweep";

local Body = require('Body')
local Config = require('Config')

local t0_ = 0;
local tScan_ = Config.fsm.headSweep.tScan;
local yawMag_ = Config.head.yawMax;
local dist_ = Config.fsm.headReady.dist;
local direction_ = 1;

local entry = function()
  print("HeadFSM: ".._NAME.." entry")
  t0_ = Body.get_time();
  --headAngles = Body.get_sensor_headpos();--123456
  local headAngles = {Body.get_sensor_headpos()[2],
                      Body.get_sensor_headpos()[1]};	--b51
  if (headAngles[1] > 0) then
    direction_ = 1;
  else
    direction_ = -1;
  end
end

local update = function()
  local t = Body.get_time();
  local ph = (t-t0_)/tScan_;
  local height = vcm.get_camera_height();
  --print("headsweep height :",height);
  local yaw0 = direction_*(ph-0.5)*2*yawMag_;
  local yaw, pitch = HeadTransform.ikineCam(dist_ * math.cos(yaw0),
                                            dist_ * math.sin(yaw0),
                                            height);
  Body.set_head_command({yaw, pitch});
  Body.set_para_headpos(vector.new({yaw, pitch}));--123456î^²¿
  Body.set_state_headValid(1);--123456î^²¿

  if (t - t0_ > tScan_) then
    return 'done';
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
