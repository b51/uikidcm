module(..., package.seeall);

require('carray');
require('vector');
require('Config');

require('ImagePreProc');
require('HeadTransform');

require('dlvcm');
require('mcm');
require('Body');

require('Camera');
require('DLDetection');

if (Config.camera.width ~= Camera.get_width()
    or Config.camera.height ~= Camera.get_height()) then
  print('Camera width/height mismatch');
  print('Config width/height = ('..Config.camera.width..', '..Config.camera.height..')');
  print('Camera width/height = ('..Camera.get_width()..', '..Camera.get_height()..')');
  error('Config file is not set correctly for this camera. Ensure the camera width and height are correct.');
end

currVel = vector.zeros(3);

dlvcm.set_image_width(Config.camera.width);
dlvcm.set_image_height(Config.camera.height);

-- camera
camera = {};
camera.width = Camera.get_width();
camera.height = Camera.get_height();
camera.npixel = camera.width*camera.height;
camera.mjpg = Camera.get_image();
camera.status = Camera.get_camera_status();
camera.switchFreq = Config.camera.switchFreq;
camera.ncamera = Config.camera.ncamera;

-- preproc
preproc = {};

-- net
net = {};
net.width = Config.net.width;
net.height = Config.net.height;
net.prototxt = Config.net.prototxt;
net.model = Config.net.model;
net.object_thresh = Config.net.object_thresh
net.nms_thresh = Config.net.nms_thresh
net.hier_thresh = Config.net.hier_thresh

saveCount = 0;

-- debugging settings
dlvcm.set_debug_enable_shm_copy(Config.vision.copy_image_to_shm);
dlvcm.set_debug_store_goal_detections(Config.vision.store_goal_detections);
dlvcm.set_debug_store_ball_detections(Config.vision.store_ball_detections);
dlvcm.set_debug_store_all_images(Config.vision.store_all_images);

-- Timing
count = 0;
lastImageCount = {0,0};
t0 = unix.time();

function entry()
  --Temporary value.. updated at body FSM at next frame
  dlvcm.set_camera_bodyHeight(Config.walk.bodyHeight);
  dlvcm.set_camera_height(Config.walk.bodyHeight+Config.head.neckZ);
	dlvcm.set_camera_ncamera(Config.camera.ncamera);

  -- Start the HeadTransform machine
  HeadTransform.entry();
  camera_init();
  ImagePreProc.init(camera.mjpg.data, camera.mjpg.size);
  --DLDetection.detector_yolo_init(net.prototxt,
  --                               net.model,
  --                               net.object_thresh,
  --                               net.nms_thresh,
  --                               net.hier_thresh);
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

  -- get mjpg image from camera
  -- mjpg = {size, data}
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

  if camera.mjpg.data == -2 then
    print "Re-enqueuing of a buffer error...";
    exit()
  end

  dlvcm.set_image_mjpg(camera.mjpg.data)
  dlvcm.set_image_mjpgSize(camera.mjpg.size)
  -- Convert mjpg to rgb
  dlvcm.set_image_rgb(ImagePreProc.mjpg_to_rgb(dlvcm.get_image_mjpg(),
                                               dlvcm.get_image_mjpgSize(),
                                               camera.width, 
                                               camera.height));

  -- Resize rgb fro net input
  --[[
  dlvcm.set_image_rgb4net(ImagePreProc.rgb_resize(dlvcm.get_image_rgb(),
                                                  camera.width,
                                                  camera.height,
                                                  net.width,
                                                  net.height));
                                                  --]]

  -- TODO(b51): Return bboxes need to be added
  DLDetection.bboxes_detect(dlvcm.get_image_rgb4net());
  update_shm(status, headAngles)
--  Detection.update();
--  dlvcm.refresh_debug_message();

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

--  if dlvcm.get_debug_enable_shm_copy() == 1 then
--    if ((dlvcm.get_debug_store_all_images() == 1)
--      or (ball.detect == 1
--          and dlvcm.get_debug_store_ball_detections() == 1)
--      or ((goalCyan.detect == 1 or goalYellow.detect == 1)
--          and dlvcm.get_debug_store_goal_detections() == 1)) then
--
--      if dlvcm.get_camera_broadcast() > 0 then --Wired monitor broadcasting
--	      if dlvcm.get_camera_broadcast() == 1 then
--	    --Level 1: 1/4 yuyv, labelB
--          dlvcm.set_image_yuyv3(ImageProc.subsample_yuyv2yuyv(
--          dlvcm.get_image_yuyv(),
--	        camera.width/2, camera.height,4));
--          dlvcm.set_image_labelB(labelB.data);
--        elseif dlvcm.get_camera_broadcast() == 2 then
--	    --Level 2: 1/2 yuyv, labelA, labelB
--          dlvcm.set_image_yuyv2(ImageProc.subsample_yuyv2yuyv(
--          dlvcm.get_image_yuyv(),
--          camera.width/2, camera.height,2));
--          dlvcm.set_image_labelA(labelA.data);
--          dlvcm.set_image_labelB(labelB.data);
--	      else
--	    --Level 3: 1/2 yuyv
--          dlvcm.set_image_yuyv2(ImageProc.subsample_yuyv2yuyv(
--          dlvcm.get_image_yuyv(),
--          camera.width/2, camera.height,2));
--	      end
--
--	    elseif dlvcm.get_camera_teambroadcast() > 0 then --Wireless Team broadcasting
--          --Only copy labelB
--          dlvcm.set_image_labelB(labelB.data);
--      end
--    end
--  end

  dlvcm.set_image_select(status.select);
  dlvcm.set_image_count(status.count);
  dlvcm.set_image_time(status.time);
  dlvcm.set_image_headAngles(headAngles);
  dlvcm.set_image_horizonA(HeadTransform.get_horizonA());
  dlvcm.set_image_horizonB(HeadTransform.get_horizonB());
  dlvcm.set_image_horizonDir(HeadTransform.get_horizonDir())

  update_shm_fov();
end

function update_shm_fov()
  --This function projects the boundary of current labeled image

  local fovC={Config.camera.width/2,Config.camera.height/2};
  local fovBL={0,Config.camera.height};
  local fovBR={Config.camera.width,Config.camera.height};
  local fovTL={0,0};
  local fovTR={Config.camera.width,0};

  dlvcm.set_image_fovC(vector.slice(HeadTransform.projectGround(
 	  HeadTransform.coordinatesA(fovC,0.1)),1,2));
  dlvcm.set_image_fovTL(vector.slice(HeadTransform.projectGround(
 	  HeadTransform.coordinatesA(fovTL,0.1)),1,2));
  dlvcm.set_image_fovTR(vector.slice(HeadTransform.projectGround(
 	  HeadTransform.coordinatesA(fovTR,0.1)),1,2));
  dlvcm.set_image_fovBL(vector.slice(HeadTransform.projectGround(
 	  HeadTransform.coordinatesA(fovBL,0.1)),1,2));
  dlvcm.set_image_fovBR(vector.slice(HeadTransform.projectGround(
 	  HeadTransform.coordinatesA(fovBR,0.1)),1,2));
end


function exit()
  HeadTransform.exit();
end

function bboxStats(color, bboxB, rollAngle, scale)
  scale = scale or scaleB;
  bboxA = {};
  bboxA[1] = scale*bboxB[1];
  bboxA[2] = scale*bboxB[2] + scale - 1;
  bboxA[3] = scale*bboxB[3];
  bboxA[4] = scale*bboxB[4] + scale - 1;
  if rollAngle then
 --hack: shift boundingbox 1 pix helps goal detection
 --not sure why this thing is happening...

--    bboxA[1]=bboxA[1]+1;
      bboxA[2]=bboxA[2]+1;

    return ImageProc.tilted_color_stats(
	labelA.data, labelA.m, labelA.n, color, bboxA,rollAngle);
  else
    return ImageProc.color_stats(labelA.data, labelA.m, labelA.n, color, bboxA);
  end
end

function ballColorBboxStats(color, bboxA)
  return ImageProc.ball_color_stats(labelA.ballData, labelA.m, labelA.n, color, bboxA);
end

function bboxB2A(bboxB)
  bboxA = {};
  bboxA[1] = scaleB*bboxB[1];
  bboxA[2] = scaleB*bboxB[2] + scaleB - 1;
  bboxA[3] = scaleB*bboxB[3];
  bboxA[4] = scaleB*bboxB[4] + scaleB - 1;
  return bboxA;
end

function bboxArea(bbox)
  return (bbox[2] - bbox[1] + 1) * (bbox[4] - bbox[3] + 1);
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
