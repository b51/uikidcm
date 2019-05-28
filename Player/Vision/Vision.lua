module(..., package.seeall);

require('carray');
require('vector');
require('Config');
-- Enable Webots specific
if (string.find(Config.platform.name,'Webots')) then
  webots = 1;
end
--Added for webots fast simulation
use_gps_only = Config.use_gps_only or 0;
require('ImageProc');
require('DLImageProc');
require('HeadTransform');

require('vcm');
require('mcm');
require('Body');

obs_challenge_enable = Config.obs_challenge or 0;
enable_lut_for_obstacle = Config.vision.enable_lut_for_obstacle or 0;
black_depth = Config.vision.black_depth or 8
black_width = Config.vision.black_width or 8
lut_stage = Config.vision.lut_stage or 64
use_arbitrary_ball = Config.vision.use_arbitrary_ball or false;

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

camera = {};

camera.width = Camera.get_width();
camera.height = Camera.get_height();
camera.npixel = camera.width*camera.height;
camera.image = Camera.get_image();
camera.status = Camera.get_camera_status();
camera.switchFreq = Config.camera.switchFreq;
camera.ncamera = Config.camera.ncamera;

-- net
net = {};
net.input_width = Config.net.input_width;
net.input_height = Config.net.input_height;
net.prototxt = Config.net.prototxt;
net.object_thresh = Config.net.thresh
net.nms_thresh = Config.net.nms_thresh
net.hier_thresh = Config.net.hier_thresh
net.log_interval = Config.net.log_interval

-- Initialize the Labeling
labelA = {};
-- labeled image is 1/4 the size of the original
labelA.m = camera.width/2;
labelA.n = camera.height/2;
labelA.npixel = labelA.m*labelA.n;

scaleB = Config.vision.scaleB;
labelB = {};
labelB.m = labelA.m/scaleB;
labelB.n = labelA.n/scaleB;
labelB.npixel = labelB.m*labelB.n;
vcm.set_image_scaleB(Config.vision.scaleB);
print('Vision LabelA size: ('..labelA.m..', '..labelA.n..')');
print('Vision LabelB size: ('..labelB.m..', '..labelB.n..')');

colorOrange = Config.color.orange;
colorYellow = Config.color.yellow;
colorCyan = Config.color.cyan;
colorField = Config.color.field;
colorWhite = Config.color.white;

yellowGoalCountThres = Config.vision.yellow_goal_count_thres;

saveCount = 0;

use_point_goal = Config.vision.use_point_goal or 0;
subsampling = Config.vision.subsampling or 0;
subsampling2 = Config.vision.subsampling2 or 0;

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
--  vcm.set_camera_bodyTilt(0);
  vcm.set_camera_height(Config.walk.bodyHeight+Config.head.neckZ);
	vcm.set_camera_ncamera(Config.camera.ncamera);

  -- Start the HeadTransform machine
  HeadTransform.entry();

  -- Initiate Detection
  Detection.entry();

  --set to switch cameras. 
  -- Load the lookup table

	if(use_arbitrary_ball) then
		print('loading environment lut: '..Config.camera.lut_file);
		camera.lut = load_general_lut(Config.camera.lut_file);

		print('loading ball lut: '..Config.camera.lut_ball_file);
		camera.lut_ball = load_general_lut(Config.camera.lut_ball_file);
		--writeSplittedBallLut('ballLut.txt', camera.lut_ball)

		print('creating splitted ball lut');
		camera.splittedBallLut = split_ball_lut(camera.lut,camera.lut_ball);
		--writeSplittedBallLut('splittedLut.txt', camera.splittedBallLut)
		--print('exiting the test routine')
		--os.exit()

		print('temp test for transfering of field color from ball lut to env lut');
		camera.lut = add_ballfield_lut(camera.lut,camera.lut_ball);
		--writeSplittedBallLut('envLut.txt', camera.lut)
		--print('exiting the test routine')
		--os.exit()
	else
		camera.lut = load_general_lut(Config.camera.lut_file);
	end

  --ADDED to prevent crashing with old camera config
  if Config.camera.lut_file_obs == null then
    Config.camera.lut_file_obs = Config.camera.lut_file;
  end

  -- Load the obstacle LUT as well
  if enable_lut_for_obstacle == 1 then
    print('loading obs lut: '..Config.camera.lut_file_obs);
    camera.lut_obs = carray.new('c', 262144);
    load_lut_obs(Config.camera.lut_file_obs);
  end

  camera_init();

  -- in default, use prelearned colortable
  vcm.set_image_learn_lut(0);
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

function camera_init_naov4()
  for c=1,Config.camera.ncamera do
    Camera.select_camera(c-1);   
    Camera.set_param('Brightness', Config.camera.brightness);     
    Camera.set_param('White Balance, Automatic', 1); 
    Camera.set_param('Auto Exposure',0);
    for i,param in ipairs(Config.camera.param) do
      Camera.set_param(param.key, param.val[c]);
      unix.usleep (100);
    end
    Camera.set_param('White Balance, Automatic', 0);
    Camera.set_param('Auto Exposure',0);
    local expo = Camera.get_param('Exposure');
    local gain = Camera.get_param('Gain');
    Camera.set_param('Auto Exposure',1);   
    Camera.set_param('Auto Exposure',0);
    --Camera.set_param ('Exposure', 255);
    Camera.set_param ('Exposure', expo);
    Camera.set_param ('Gain', gain);
    print('Camera #'..c..' set');
  end
end


function update()
  --If we are only using gps info, skip whole vision update 	
  if use_gps_only>0 then
    update_gps_only();
    return true;
  end

  tstart = unix.time();
  
  headAngles = {Body.get_sensor_headpos()[2],Body.get_sensor_headpos()[1]};	--b51

  -- get image from camera
  camera.image = Camera.get_image();
  local status = Camera.get_camera_status();
  if status.count ~= lastImageCount[status.select+1] then
    lastImageCount[status.select+1] = status.count;
  else
    return false; 
  end
  -- Add timer measurements
  count = count + 1;
  --headAngles = Body.get_head_position();
--  HeadTransform.update(status.select, headAngles, compensateY);
  HeadTransform.update(status.select, headAngles);

--SJ: Camera image keeps changing
--So copy it here to shm, and use it for all vision process
  vcm.set_image_yuyv(camera.image);


  if camera.image == -2 then
    print "Re-enqueuing of a buffer error...";
    exit()
  end
  camera.rgb = DLImageProc.yuyv_to_rgb(vcm.get_image_yuyv(), camera.width, camera.height);

  -- perform the initial labeling
  if webots == 1 then
    labelA.data = Camera.get_labelA( carray.pointer(camera.lut) );
  else

		if(use_arbitrary_ball) then
			labelA.data, labelA.dataBall  = ImageProc.yuyv_to_label_ball(vcm.get_image_yuyv(),
																						carray.pointer(camera.lut),
																						carray.pointer(camera.splittedBallLut),
																						camera.width/2,
																						camera.height);
		else
			labelA.data  = ImageProc.yuyv_to_label(vcm.get_image_yuyv(),
																						carray.pointer(camera.lut),
																						camera.width/2,
																						camera.height);
		end

  end

	--print('exiting the test routine')
	--os.exit()

  -- determine total number of pixels of each color/label
  colorCount = ImageProc.color_count(labelA.data, labelA.npixel);

  -- bit-or the segmented image
  labelB.data = ImageProc.block_bitor(labelA.data, labelA.m, labelA.n, scaleB, scaleB);

  update_shm(status, headAngles)

  vcm.refresh_debug_message();

  Detection.update();
  vcm.refresh_debug_message();

  -- switch camera
  local cmd = vcm.get_camera_command();
  if (cmd == -1) then
    if (count % camera.switchFreq == 0) then
       Camera.select_camera(1-Camera.get_select()); 
    end
  else
    if (cmd >= 0 and cmd < camera.ncamera) then
      Camera.select_camera(cmd);
    else
      print('WARNING: attempting to switch to unkown camera select = '..cmd);
    end
  end
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

function update_gps_only()
  --We are now using ground truth robot and ball pose data
--  headAngles = Body.get_head_position();
  headAngles = {Body.get_sensor_headpos()[2],Body.get_sensor_headpos()[1]};	--b51
  --TODO: camera select
--  HeadTransform.update(status.select, headAngles);
  HeadTransform.update(0, headAngles);
  
  --update FOV
  update_shm_fov()

  --Get GPS coordinate of robot and ball
  gps_pose = wcm.get_robot_gpspose();
  ballGlobal=wcm.get_robot_gps_ball();  
  
  --Check whether ball is inside FOV
  ballLocal = util.pose_relative(ballGlobal,gps_pose);
 
  --Get the coordinates of FOV boundary
  local v_TL = vcm.get_image_fovTL();
  local v_TR = vcm.get_image_fovTR();
  local v_BL = vcm.get_image_fovBL();
  local v_BR = vcm.get_image_fovBR();

--[[
print("BallLocal:",unpack(ballLocal))
print("V_TL:",unpack(v_TL))
print("V_TR:",unpack(v_TR))
print("V_BL:",unpack(v_BL))
print("V_BR:",unpack(v_BR))
print("Check 1:",
   check_side(v_TL, ballLocal, v_TR));
print("Check 2:",
     check_side(v_TL, v_BL, ballLocal) );
print("Check 3:",
     check_side(v_BR, v_TR, ballLocal) );
print("Check 4:",
     check_side(v_BL, v_BR, ballLocal) );
--]]

  --Check whether ball is within FOV boundary 
  if check_side(v_TR, v_TL, ballLocal) < 0 and
     check_side(v_TL, v_BL, ballLocal) < 0 and
     check_side(v_BR, v_TR, ballLocal) < 0 and
     check_side(v_BL, v_BR, ballLocal) < 0 then
    vcm.set_ball_detect(1);
  else
    vcm.set_ball_detect(0);
  end


end

function update_shm(status, headAngles)
  -- Update the shared memory
  -- Shared memory size argument is in number of bytes

  if vcm.get_debug_enable_shm_copy() == 1 then
    if ((vcm.get_debug_store_all_images() == 1)
      or (ball.detect == 1
          and vcm.get_debug_store_ball_detections() == 1)
      or ((goalCyan.detect == 1 or goalYellow.detect == 1)
          and vcm.get_debug_store_goal_detections() == 1)) then

      if vcm.get_camera_broadcast() > 0 then --Wired monitor broadcasting
	      if vcm.get_camera_broadcast() == 1 then
	    --Level 1: 1/4 yuyv, labelB
          vcm.set_image_yuyv3(ImageProc.subsample_yuyv2yuyv(
          vcm.get_image_yuyv(),
	        camera.width/2, camera.height,4));
          vcm.set_image_labelB(labelB.data);
        elseif vcm.get_camera_broadcast() == 2 then
	    --Level 2: 1/2 yuyv, labelA, labelB
          vcm.set_image_yuyv2(ImageProc.subsample_yuyv2yuyv(
          vcm.get_image_yuyv(),
          camera.width/2, camera.height,2));
          vcm.set_image_labelA(labelA.data);
          vcm.set_image_labelB(labelB.data);
	      else
	    --Level 3: 1/2 yuyv
          vcm.set_image_yuyv2(ImageProc.subsample_yuyv2yuyv(
          vcm.get_image_yuyv(),
          camera.width/2, camera.height,2));
	      end

	    elseif vcm.get_camera_teambroadcast() > 0 then --Wireless Team broadcasting
          --Only copy labelB
          vcm.set_image_labelB(labelB.data);
      end
    end
  end

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

function load_lut_camera(fname)
  local cwd = unix.getcwd();
  if string.find(cwd, "WebotsController") then
    cwd = cwd.."/Player";
  end
  cwd = cwd.."/Data/";
  local f = io.open(cwd..fname, "r");
  assert(f, "Could not open lut file");
  local s = f:read("*a");
  for i = 1,string.len(s) do
    camera.lut[i] = string.byte(s,i,i);
  end
end

function load_lut_ball(fname)
  local cwd = unix.getcwd();
  cwd = cwd.."/Data/";
  local f = io.open(cwd..fname, "r");
  assert(f, "Could not open lut ball file");
  local s = f:read("*a");
  for i = 1,string.len(s) do
    camera.lut_ball[i] = string.byte(s,i,i);
  end
end

function writeSplittedBallLut(fname,lutContents)
  local cwd = unix.getcwd();
  cwd = cwd.."/Data/";

  local f = io.open(cwd..fname, "w");
  assert(f, "Could not open lut file");

	local lutLength = #lutContents;
  for i = 1, lutLength do
    f:write(lutContents[i], ",");
  end

	f:write("\n");
	
end

function load_general_lut(fname)
	local ta = carray.new('c',262144)

  local cwd = unix.getcwd();
  if string.find(cwd, "WebotsController") then
    cwd = cwd.."/Player";
  end
  cwd = cwd.."/Data/";

  local f = io.open(cwd..fname, "r");
  assert(f, "Could not open lut file");
  local s = f:read("*a");

	print('raw file length ='.. string.len(s))
  for i = 1,string.len(s) do
    ta[i] = string.byte(s,i,i);
  end
	
	return ta;
end

function load_lut_obs(fname)
  local cwd = unix.getcwd();
  if string.find(cwd, "WebotsController") then
    cwd = cwd.."/Player";
  end
  cwd = cwd.."/Data/";
  local f = io.open(cwd..fname, "r");
  assert(f, "Could not open lut file");
  local s = f:read("*a");
  for i = 1,string.len(s) do
    camera.lut_obs[i] = string.byte(s,i,i);
  end
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

function isAlsoBlackColor(y,u,v)
	uvRange = {(lut_stage-black_width)/2,(lut_stage+black_width)/2}

	if((u-uvRange[1])*(u-uvRange[2])<0 and
			(v-uvRange[1])*(v-uvRange[2])<0 and
			y<black_depth) then
		--print("black color found in ball", y, u, v)
		return true;
	end
	return false;
end

function add_ballfield_lut(envLut, ballLut)
  local ta = carray.new('c', 262144);

	for i = 1, 64 do
    for j = 1, 64 do
      for k = 1, 64 do

				local ind = (i-1)*64*64 + (j-1)*64 + k;
				ta[ind] = envLut[ind];

				if(ta[ind] == 8) then
					ta[ind] = 0
				end

				if (ballLut[ind] == 8 and ta[ind] == 0) then
					ta[ind] = ballLut[ind];
				end

      end
    end
  end

  return ta;
end

function split_ball_lut(envLut, ballLut)
  local ta = carray.new('c', 262144);

	for i = 1, 64 do
    for j = 1, 64 do
      for k = 1, 64 do
				local ind = (i-1)*64*64 + (j-1)*64 + k;
				--ta[ind] = ballLut[ind];
				if (ballLut[ind]==1) then
					if(envLut[ind]==2 or envLut[ind]==16) then
						ta[ind] = 4
					elseif(isAlsoBlackColor(i,j,k)) then
						ta[ind] = 2
					else
						ta[ind] = 1
					end
				end
      end
    end
  end

	print("splitted lut for the ball is")
	print(ta)

  return ta;
end

--[[
function substract_lut(lut1, lut2, color1, color2)
  local lut = {};
  local validPoints = {};

  for i = 1, 64 do
    lut[i] = {};
    for j = 1, 64 do
      lut[i][j] = {};
      for k = 1, 64 do
        if lut1[i][j][k] == color1 then
          if lut2[i][j][k] ~= color2 then
            lut[i][j][k] = color1;
            validPoints = vector.new({i, j, k, color1});
          else
            lut[i][j][k] = 0;
          end
        else
          lut[i][j][k] = 0;
        end
      end
    end
  end
  return validPoints, lut; 
end

-- Create lutBall, include all ball color; lutWhite, include white and green; and lutBlack, only include black;
function create_diff_lut()
  local lutBall = {};
  local lutWhite = {};
  local lutBlack = {};
  local vpBall = {};
  local vpWhite = {};
  local vpBlack = {};
  local x = 1;
  local y = 1;

  for i = 1, 64 do
    lutBall[i] = {};
    lutWhite[i] = {};
    lutBlack[i] = {};
    for j = 1, 64 do
      lutBall[i][j] = {};
      lutWhite[i][j] = {};
      lutBlack[i][j] = {};
      for k = 1, 64 do
        if camera.lut_ball[(i-1)*64*64 + (j-1)*64 + k] ~= 0 then
          lutBall[i][j][k] = camera.lut_ball[(i-1)*64*64 + (j-1)*64 + k];
          vpBall[x] = vector.new({i, j, k, camera.lut_ball[(i-1)*64*64 + (j-1)*64 + k]});
          x = x + 1;
        else
          lutBall[i][j][k] = 0;
        end

        if camera.lut[(i-1)*64*64 + (j-1)*64 + k] ~= 0 then
          lutWhite[i][j][k] = camera.lut[(i-1)*64*64 + (j-1)*64 + k];
          vpWhite[y] = vector.new({i, j, k, camera.lut[(i-1)*64*64 + (j-1)*64 + k]});
          y = y + 1;
        else
          lutWhite[i][j][k] = 0;
        end

        lutBlack[i][j][k] = 0;
      end
    end
  end
  vpBlack, lutBlack = create_black_lut(lutBlack);

  return vpBall, lutBall, vpWhite, lutWhite, vpBlack, lutBlack;
end

-- this function can be omitted because it is an rect area
function create_black_lut(stage, tag, blackWidth, blackDepth)
	local ta = carray.new(stage*stage*stage);
	local uvRange=fix([(stage-blackWidth)/2,(stage+blackWidth)/2]);

for i = uvRange(1):uvRange(2)
    for j = uvRange(1):uvRange(2)
        for k = 1:blackDepth
            lut(i,j,k)=uint8(tag);
            validPoints=[validPoints;i,j,k,lut(i,j,k)];
  
  return ta;
end
--]]

