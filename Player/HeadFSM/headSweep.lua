--SJ: New headSweep using camera inverse kinematics

module(..., package.seeall);

require('Body')

t0 = 0;
tScan = Config.fsm.headSweep.tScan;
yawMag = Config.head.yawMax;
dist = Config.fsm.headReady.dist;

function entry()
print("headSweep entry")
  print(_NAME..' entry');

  t0 = Body.get_time();
  --headAngles = Body.get_sensor_headpos();--123456
  headAngles = {Body.get_sensor_headpos()[2],Body.get_sensor_headpos()[1]};	--b51
  if (headAngles[1] > 0) then
    direction = 1;
  else
    direction = -1;
  end
end

function update()
  local t = Body.get_time();
  local ph = (t-t0)/tScan;
  local height=vcm.get_camera_height();
  --print("headsweep height :",height);
  local yaw0 = direction*(ph-0.5)*2*yawMag;
  local yaw, pitch =HeadTransform.ikineCam(
	dist*math.cos(yaw0),dist*math.sin(yaw0), height);

--	pitch = pitch - 30;		--b51
--	print("pitch :"..pitch);	--b51
  Body.set_head_command({yaw, pitch});
--	print("headsweep pitch :",pitch);
  Body.set_para_headpos(vector.new({yaw, pitch}));--123456î^²¿
  Body.set_state_headValid(1);--123456î^²¿

  if (t - t0 > tScan) then
    return 'done';
  end
end

function exit()
end
