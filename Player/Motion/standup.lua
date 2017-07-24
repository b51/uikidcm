module(..., package.seeall);

require('Body')
require('keyframe')
require('unix')
require('Config');
require('walk');
require('wcm')
require('mcm')

local cwd = unix.getcwd();
if string.find(cwd, "WebotsController") then
  cwd = cwd.."/Player";
end
cwd = cwd.."/Motion/keyframes"

keyframe.load_motion_file(cwd.."/"..Config.km.standup_front,
                          "standupFromFront");
keyframe.load_motion_file(cwd.."/"..Config.km.standup_back,
                          "standupFromBack");

use_rollback_getup = Config.use_rollback_getup or 0;
batt_max = Config.batt_max or 10;

function entry()
  print(_NAME.." entry");

  keyframe.entry();
  Body.set_body_hardness(1);
  -- start standup routine (back/front)
  local imuAngleY = Body.get_sensor_imuAngle(2);
  if (imuAngleY > 0) then
    print("standupFromFront");
    keyframe.do_motion("standupFromFront");
    mcm.set_motion_fall_check(0);         ---------------tse
		Body.set_para_gaitID(vector.new({3,1}));------------123456起立 开始
		Body.set_state_specialValid(1);------------123456起立 开始
  else
    pose = wcm.get_pose();
    batt_level=Body.get_battery_level();

    if math.abs(pose.x) < 2.0 and
       use_rollback_getup > 0 and
       batt_level*10>batt_max then

      print("standupFromBack");
      keyframe.do_motion("standupFromBack2");
    else
      print("standupFromBack");
      keyframe.do_motion("standupFromBack");
    end
    mcm.set_motion_fall_check(0);                ----------------tse
		Body.set_para_gaitID(vector.new({4,1}));------------123456起立 开始
		Body.set_state_specialValid(1);------------123456起立 开始
  end
  t0 = Body.get_time();
end

function update()
  keyframe.update();

	t = Body.get_time();
	if(t-t0>8.0) then
		print('time waiting for', t - t0, 'is completed');
		specialValid = Body.get_state_specialValid()--123456判斷是否后於結束
		isComplete = Body.get_state_specialGaitPending();
		if (keyframe.get_queue_len() == 0 and specialValid[1] == 0 and isComplete[1] == 0) then--123456判斷是否后於結束
			local imuAngle = Body.get_sensor_imuAngle();
			local maxImuAngle = math.max(math.abs(imuAngle[1]),
													math.abs(imuAngle[2]));
			
			fall = mcm.get_motion_fall_check();  --tse
			if (maxImuAngle > 30*math.pi/180 and fall==1) then 
				do return "fail"; end
			else
				--Set velocity to 0 to prevent falling--
				walk.still=true;
				walk.set_velocity(0, 0, 0);
				return "done";
			end
		end
	end

end

function exit()
  keyframe.exit();
	mcm.set_motion_fall_check(1);               --------------tse
end
