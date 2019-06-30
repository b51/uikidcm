module(..., package.seeall);

require('carray');
require('vector');
require('Config');

require('ImagePreProc');
require('HeadTransform');

require('vcm');
require('mcm');
require('Body');

currVel = vector.zeros(3);

require('Camera');
require('Detection');

if (Config.camera.width ~= Camera.get_width()
    or Config.camera.height ~= Camera.get_height()) then
  print('Camera width/height mismatch');
  print('Config width/height = ('..Config.camera.width..', '..Config.camera.height..')');
  print('Camera width/height = ('..Camera.get_width()..', '..Camera.get_height()..')');
  error('Config file is not set correctly for this camera. Ensure the camera width and height are correct.');
end
vcm.set_image_width(Config.camera.width);
vcm.set_image_height(Config.camera.height);

-- camera
camera = {};
camera.width = Camera.get_width();
camera.height = Camera.get_height();
camera.npixel = camera.width*camera.height;
camera.mjpg = Camera.get_image();
camera.status = Camera.get_camera_status();
camera.switchFreq = Config.camera.switchFreq;
camera.ncamera = Config.camera.ncamera;

-- net
net = {};
net.width = Config.net.width;
net.height = Config.net.height;
net.ratio_fixed = Config.net.ratio_fixed;

saveCount = 0;

-- debugging settings
vcm.set_debug_enable_shm_copy(Config.vision.copy_image_to_shm);
vcm.set_debug_store_goal_detections(Config.vision.store_goal_detections);
vcm.set_debug_store_ball_detections(Config.vision.store_ball_detections);
vcm.set_debug_store_all_images(Config.vision.store_all_images);

-- Timing
count = 0;
lastImageCount = {0,0};
t0 = unix.time();

function entry()
  --Temporary value.. updated at body FSM at next frame
  vcm.set_camera_bodyHeight(Config.walk.bodyHeight);
  vcm.set_camera_height(Config.walk.bodyHeight+Config.head.neckZ);
	vcm.set_camera_ncamera(Config.camera.ncamera);

  -- Start the HeadTransform machine
  HeadTransform.entry();

  -- Initiate Detection
  Detection.entry();

  -- Initiate OPCam
  camera_init();

  -- Initiate ImagePreProc
  ImagePreProc.init(camera.mjpg.data, camera.mjpg.size);
end

function camera_init()
  for c=1,Config.camera.ncamera do
    Camera.select_camera(c-1);
    for i,auto_param in ipairs(Config.camera.auto_param) do
      print('Camera '..c..': setting '..auto_param.key..': '..auto_param.val[c]);
      Camera.set_param(auto_param.key, auto_param.val[c]);
      unix.usleep(100000);
      print('Camera '..c..': check '..auto_param.key..' now is: '..Camera.get_param(auto_param.key));
    end
    for i,param in ipairs(Config.camera.param) do
      print('Camera '..c..': setting '..param.key..': '..param.val[c]);
      Camera.set_param(param.key, param.val[c]);
      unix.usleep(10000);
      print('Camera '..c..': check '..param.key..' now is: '..Camera.get_param(param.key));
    end
  end
end

function update()
  tstart = unix.time();
  headAngles = {Body.get_sensor_headpos()[2],Body.get_sensor_headpos()[1]};	--b51
  -- get mjpg image from camera, mjpg format: {size, data}
  camera.mjpg = Camera.get_image();
  local status = Camera.get_camera_status();
  if status.count ~= lastImageCount[status.select+1] then
    lastImageCount[status.select+1] = status.count;
  else
    return false;
  end
  -- Add timer measurements
  count = count + 1;
  HeadTransform.update(status.select, headAngles);
  -- Convert mjpg to rgb
  local save_image = vcm.get_image_save() or 0;
  local rgb = ImagePreProc.mjpg_to_rgb(camera.mjpg.data,
                                       camera.mjpg.size,
                                       camera.width,
                                       camera.height);
  -- Resize rgb fro net input
  local rzdrgb = ImagePreProc.rgb_resize(rgb,
                                          camera.width,
                                          camera.height,
                                          net.width,
                                          net.height,
                                          net.ratio_fixed,
                                          save_image);
  vcm.set_image_rzdrgb(rzdrgb);
  update_shm(status, headAngles)

  vcm.refresh_debug_message();

  Detection.update();
  vcm.refresh_debug_message();
  return true;
end

function check_side(v,v1,v2)
  --find the angle from the vector v-v1 to vector v-v2
  local vel1 = {v1[1]-v[1],v1[2]-v[2]};
  local vel2 = {v2[1]-v[1],v2[2]-v[2]};
  angle1 = math.atan2(vel1[2],vel1[1]);
  angle2 = math.atan2(vel2[2],vel2[1]);
  return util.mod_angle(angle1-angle2);
end

function update_shm(status, headAngles)
  -- Update the shared memory
  -- Shared memory size argument is in number of bytes

--  if vcm.get_debug_enable_shm_copy() == 1 then
--    if ((vcm.get_debug_store_all_images() == 1)
--      or (ball.detect == 1
--          and vcm.get_debug_store_ball_detections() == 1)
--      or ((goalCyan.detect == 1 or goalYellow.detect == 1)
--          and vcm.get_debug_store_goal_detections() == 1)) then
--
--      if vcm.get_camera_broadcast() > 0 then --Wired monitor broadcasting
--	      if vcm.get_camera_broadcast() == 1 then
--	    --Level 1: 1/4 yuyv, labelB
--          vcm.set_image_yuyv3(ImageProc.subsample_yuyv2yuyv(
--          vcm.get_image_yuyv(),
--	        camera.width/2, camera.height,4));
--          vcm.set_image_labelB(labelB.data);
--        elseif vcm.get_camera_broadcast() == 2 then
--	    --Level 2: 1/2 yuyv, labelA, labelB
--          vcm.set_image_yuyv2(ImageProc.subsample_yuyv2yuyv(
--          vcm.get_image_yuyv(),
--          camera.width/2, camera.height,2));
--          vcm.set_image_labelA(labelA.data);
--          vcm.set_image_labelB(labelB.data);
--	      else
--	    --Level 3: 1/2 yuyv
--          vcm.set_image_yuyv2(ImageProc.subsample_yuyv2yuyv(
--          vcm.get_image_yuyv(),
--          camera.width/2, camera.height,2));
--	      end
--
--	    elseif vcm.get_camera_teambroadcast() > 0 then --Wireless Team broadcasting
--          --Only copy labelB
--          vcm.set_image_labelB(labelB.data);
--      end
--    end
--  end

  vcm.set_image_select(status.select);
  vcm.set_image_count(status.count);
  vcm.set_image_time(status.time);
  vcm.set_image_headAngles(headAngles);
  vcm.set_image_horizonA(HeadTransform.get_horizonA());
  vcm.set_image_horizonB(HeadTransform.get_horizonB());
  vcm.set_image_horizonDir(HeadTransform.get_horizonDir())

  update_shm_fov();
end

function update_shm_fov()
  --This function projects the boundary of current labeled image

  local fovC={Config.camera.width/2,Config.camera.height/2};
  local fovBL={0,Config.camera.height};
  local fovBR={Config.camera.width,Config.camera.height};
  local fovTL={0,0};
  local fovTR={Config.camera.width,0};

  vcm.set_image_fovC(vector.slice(HeadTransform.projectGround(
	  HeadTransform.coordinatesA(fovC,0.1)),1,2));
  vcm.set_image_fovTL(vector.slice(HeadTransform.projectGround(
	  HeadTransform.coordinatesA(fovTL,0.1)),1,2));
  vcm.set_image_fovTR(vector.slice(HeadTransform.projectGround(
	  HeadTransform.coordinatesA(fovTR,0.1)),1,2));
  vcm.set_image_fovBL(vector.slice(HeadTransform.projectGround(
	  HeadTransform.coordinatesA(fovBL,0.1)),1,2));
  vcm.set_image_fovBR(vector.slice(HeadTransform.projectGround(
	  HeadTransform.coordinatesA(fovBR,0.1)),1,2));
end


function exit()
  HeadTransform.exit();
end

function save_rgb(rgb)
  saveCount = saveCount + 1;
  local filename = string.format("/tmp/rgb_%03d.raw", saveCount);
  local f = io.open(filename, "w+");
  assert(f, "Could not open save image file");
  for i = 1,3*camera.width*camera.height do
    local c = rgb[i];
    if (c < 0) then
      c = 256+c;
    end
    f:write(string.char(c));
  end
  f:close();
end
