--SJ: camera IK based constant sweeping
local _NAME = "headReady";

local Body = require('Body')
local Config = require('Config')

local t0_ = 0;
local dist_ = Config.fsm.headReady.dist;
local yawMag_ = Config.head.yawMax;
local tScan_ = Config.fsm.headReady.tScan;
local direction_;

local entry = function()
  print("HeadFSM: ".._NAME.." entry");
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
  local ph = (t-t0)/tScan;
  local height = vcm.get_camera_height();

  --IK based horizon following
  local yaw0 = direction_*(ph-0.5)*2*yawMag_;
  -- TODO(b51): ikineCam need be fixed
  local yaw, pitch = HeadTransform.ikineCam(dist_ * math.cos(yaw0),
                                            dist_ * math.sin(yaw0),
                                            height);
  --ignore headangle limit for testing
  local yaw, pitch = HeadTransform.ikineCam0(dist_ * math.cos(yaw0),
                                             dist_ * math.sin(yaw0),
                                             height);
	pitch = pitch + 5 * math.pi/180;
  Body.set_head_command({yaw, pitch});

  Body.set_para_headpos(vector.new({yaw, pitch}));--123456î^²¿
  Body.set_state_headValid(1);--123456î^²¿

  if (t - t0_ > tScan_) then
   return 'done'
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
