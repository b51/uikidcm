module(..., package.seeall);

require('Config');	-- For Ball and Goal Size
require('ImageProc');
require('HeadTransform');	-- For Projection
require('Vision');
require('Body');
require('vcm');
require('unix');

-- Dependency
require('DLDetection');
require('detectBall');
require('detectGoal');
require('detectLine');
require('detectCorner');
if not string.find(Config.platform.name,'Nao') then
  require('detectLandmarks'); -- for NSL
  require('detectLandmarks2'); -- for NSL
end
require('detectSpot');
require('detectFreespace');
require('detectBoundary');
--[[
require('detectObstacles');
require('detectEyes');
require('detectStretcher');
--]]


--for quick test
require('detectRobot');


-- Define Color
colorOrange = Config.color.orange;
colorYellow = Config.color.yellow;
colorCyan = Config.color.cyan;
colorField = Config.color.field;
colorWhite = Config.color.white;
colorGoalAndLine = Config.color.goal_and_line;

use_point_goal=Config.vision.use_point_goal;
use_multi_landmark = Config.vision.use_multi_landmark or 0;


enableLine = Config.vision.enable_line_detection;
enableCorner = Config.vision.enable_corner_detection;
enableSpot = Config.vision.enable_spot_detection;
enableMidfieldLandmark = Config.vision.enable_midfield_landmark_detection;
enable_freespace_detection = Config.vision.enable_freespace_detection or 0;
enableBoundary = Config.vision.enable_visible_boundary or 0;
enableRobot = Config.vision.enable_robot_detection or 0;
yellowGoals = Config.world.use_same_colored_goal or 0; --Config.vision.enable_2_yellow_goals or 0;

enable_timeprinting = Config.vision.print_time;

use_arbitrary_ball = Config.vision.use_arbitrary_ball or false;

tstart = unix.time();
Tball = 0;
TgoalYellow = 0;
TgoalCyan = 0;
Tline = 0;
Tcorner = 0;
TlandmarkCyan = 0;
TlandmarkYellow = 0;
Trobot = 0;
Tfreespace = 0;
Tboundary = 0;

camera = {};
camera.width = Camera.get_width();
camera.height = Camera.get_height();
-- net
net = {};
net.width = Config.net.width;
net.height = Config.net.height;
net.ratio_fixed = Config.net.ratio_fixed;
net.prototxt = Config.net.prototxt;
net.model = Config.net.model;
net.object_thresh = Config.net.object_thresh
net.nms_thresh = Config.net.nms_thresh
net.hier_thresh = Config.net.hier_thresh

function entry()
  -- Initiate Detection
  ball = {};
  ball.detect = 0;

  ballYellow={};
  ballYellow.detect=0;

  ballCyan={};
  ballCyan.detect=0;

  goalYellow = {};
  goalYellow.detect = 0;

  goalCyan = {};
  goalCyan.detect = 0;

  landmarkYellow = {};
  landmarkYellow.detect = 0;

  landmarkCyan = {};
  landmarkCyan.detect = 0;

  line = {};
  line.detect = 0;

  corner = {};
  corner.detect = 0;

  spot = {};
  spot.detect = 0;

  obstacle={};
  obstacle.detect=0;

  freespace={};
  freespace.detect=0;

  boundary={};
  boundary.detect=0;

  DLDetection.detector_yolo_init(net.prototxt,
                                 net.model,
                                 net.object_thresh,
                                 net.nms_thresh,
                                 net.hier_thresh);
end



function update()
  -- ball detector
  tstart = unix.time();
  local show_image = 1;
  local detection = DLDetection.bboxes_detect(dlvcm.get_image_rzdrgb(),
                                              camera.width,
                                              camera.height,
                                              net.width,
                                              net.height,
                                              show_image);
  Tdetection = unix.time() - tstart;
  ball = detectBall.dldetect(detection.ball);
  --[[
  goal = detectGoal.detect(detection.goal);
  print("DLDetection tim: "..Tdetection);
  for k, v in pairs(detection) do
    print(k..":")
    for m, n in pairs(v) do
      print("    "..m..": "..n)
    end
  end
  --]]
  --[[
  tstart = unix.time();
	if(use_arbitrary_ball) then
		ball = detectBall.detect("arbitrary");
	else
		ball = detectBall.detect(colorOrange);
	end
  Tball = unix.time() - tstart;

  -- goal detector
  if use_point_goal == 1 then
    ballYellow = detectBall.detect(colorYellow);
    ballCyan = detectBall.detect(colorCyan);
  else
    goalYellow.detect=0;
    goalCyan.detect=0;
    tstart = unix.time();
	  if(use_arbitrary_ball) then
      goalYellow = detectGoal.detect(colorGoalAndLine);
	  else
      goalYellow = detectGoal.detect(colorWhite);
    end
    TgoalYellow = unix.time() - tstart;

    if yellowGoals == 0 then
      tstart = unix.time();
	  if(use_arbitrary_ball) then
      goalCyan = detectGoal.detect(colorGoalAndLine);
	  else
      goalCyan = detectGoal.detect(colorWhite);
    end
      TgoalCyan = unix.time() - tstart;
    end
  end

  -- line detection
  if enableLine == 1 then
    tstart = unix.time();
    line = detectLine.detect();
    Tline = unix.time() - tstart;
    if enableCorner == 1 then
      corner = detectCorner.detect(line);
      Tcorner = unix.time() - Tline - tstart;
    end
  end

  -- spot detection
  if enableSpot == 1 then
    spot = detectSpot.detect();
  end

  -- midfield landmark detection
  if not string.find(Config.platform.name,'Nao') then
   landmarkCyan = 0;
   landmarkYellow = 0;
   if enableMidfieldLandmark == 1 then
     if use_multi_landmark == 1 then
       landmarkCyan = detectLandmarks2.detect(colorCyan,colorYellow);
       landmarkYellow = detectLandmarks2.detect(colorYellow,colorCyan);
     else
       landmarkCyan = detectLandmarks.detect(colorCyan,colorYellow);
       landmarkYellow = detectLandmarks.detect(colorYellow,colorCyan);
     end
   end
  end

  if enable_freespace_detection ==1 then
    tstart = unix.time();
    freespace = detectFreespace.detect(colorField);
    Tfreespace = unix.time() - tstart;
    boundary = detectBoundary.detect();
    Tboundary = unix.time() - Tfreespace - tstart;
  end

  -- Global robot detection
  if enableRobot ==1 then
    tstart = unix.time();
    detectRobot.detect();
    Trobot = unix.time() - tstart;
  end
  --]]

  --update_shm();
end

function update_shm()
  vcm.set_ball_detect(ball.detect);
  if (ball.detect == 1) then
    vcm.set_ball_centroid(ball.propsA.centroid);
    vcm.set_ball_axisMajor(ball.propsA.axisMajor);
    vcm.set_ball_axisMinor(ball.propsA.axisMinor);
    vcm.set_ball_v(ball.v);
    vcm.set_ball_r(ball.r);
    vcm.set_ball_dr(ball.dr);
    vcm.set_ball_da(ball.da);
  end

  vcm.set_goal_detect(math.max(goalCyan.detect, goalYellow.detect));
  if (goalCyan.detect == 1) then
    vcm.set_goal_color(colorCyan);
    vcm.set_goal_type(goalCyan.type);
    vcm.set_goal_v1(goalCyan.v[1]);
    vcm.set_goal_v2(goalCyan.v[2]);
  elseif (goalYellow.detect == 1) then
    vcm.set_goal_color(colorYellow);
    vcm.set_goal_type(goalYellow.type);
    vcm.set_goal_v1(goalYellow.v[1]);
    vcm.set_goal_v2(goalYellow.v[2]);
  end

  -- midfield landmark detection
  vcm.set_landmark_detect(0);
  if not string.find(Config.platform.name,'Nao') then
    if enableMidfieldLandmark == 1 then
      if landmarkYellow.detect==1 then
         vcm.set_landmark_detect(1);
         vcm.set_landmark_color(colorYellow);
         vcm.set_landmark_v(landmarkYellow.v);
      elseif landmarkCyan.detect==1 then
         vcm.set_landmark_detect(1);
         vcm.set_landmark_color(colorCyan);
         vcm.set_landmark_v(landmarkCyan.v);
      end
    end
  end


  vcm.set_line_detect(line.detect);
  if (line.detect == 1) then
    local v1x = vector.zeros(12);
    local v1y = vector.zeros(12);
    local v2x = vector.zeros(12);
    local v2y = vector.zeros(12);
    local real_length = vector.zeros(12);
    local endpoint11 = vector.zeros(12);
    local endpoint12 = vector.zeros(12);
    local endpoint21 = vector.zeros(12);
    local endpoint22 = vector.zeros(12);
    local xMean = vector.zeros(12);
    local yMean = vector.zeros(12);

    max_length=0;
    max_real_length = 0;
    max_index=1;

    for i=1,line.nLines do
      v1x[i]=line.v[i][1][1];
      v1y[i]=line.v[i][1][2];
      v2x[i]=line.v[i][2][1];
      v2y[i]=line.v[i][2][2];
      real_length[i] = math.sqrt((v2x[i]-v1x[i])^2 + (v2y[i]-v1y[i])^2);
      --x0 x1 y0 y1
      endpoint11[i]=line.endpoint[i][1];
      endpoint12[i]=line.endpoint[i][3];
      endpoint21[i]=line.endpoint[i][2];
      endpoint22[i]=line.endpoint[i][4];
      xMean[i]=line.meanpoint[i][1];
      yMean[i]=line.meanpoint[i][2];
      if max_length<real_length[i] then
        max_length=real_length[i];
	      max_index=i;
      end
    end

    --TODO: check line length

    vcm.set_line_v1x(v1x);
    vcm.set_line_v1y(v1y);
    vcm.set_line_v2x(v2x);
    vcm.set_line_v2y(v2y);
    vcm.set_line_real_length(real_length);
    vcm.set_line_endpoint11(endpoint11);
    vcm.set_line_endpoint12(endpoint12);
    vcm.set_line_endpoint21(endpoint21);
    vcm.set_line_endpoint22(endpoint22);
    vcm.set_line_xMean(xMean);
    vcm.set_line_yMean(yMean);

    local max_lengthB = math.sqrt(
      (endpoint11[max_index]-endpoint21[max_index])^2+
      (endpoint12[max_index]-endpoint22[max_index])^2);
    local mean_v = {(v1x[max_index]+v2x[max_index])/2,(v1y[max_index]+v2y[max_index])/2,0,1};

    vcm.set_line_v(mean_v);
    vcm.set_line_angle(line.angle[max_index]);
    vcm.set_line_nLines(line.nLines);
    local max_real_length = real_length[max_index];
    vcm.set_line_lengthB(max_real_length);
  end

  vcm.set_corner_detect(corner.detect);
  if (corner.detect == 1) then
    vcm.set_corner_type(corner.type)
    vcm.set_corner_vc0(corner.vc0)
    vcm.set_corner_v10(corner.v10)
    vcm.set_corner_v20(corner.v20)
    vcm.set_corner_v(corner.v)
    vcm.set_corner_v1(corner.v1)
    vcm.set_corner_v2(corner.v2)
  end

  vcm.set_spot_detect(spot.detect);
  if (spot.detect == 1) then
    vcm.set_spot_v(spot.v);
    vcm.set_spot_bboxB(spot.bboxB);
    vcm.set_spot_color(colorWhite)
  end

  vcm.set_freespace_detect(freespace.detect);
  if (freespace.detect == 1) then
	vcm.set_freespace_block(freespace.block);
    vcm.set_freespace_nCol(freespace.nCol);
    vcm.set_freespace_nRow(freespace.nRow);
    vcm.set_freespace_vboundB(freespace.vboundB);
    vcm.set_freespace_pboundB(freespace.pboundB);
    vcm.set_freespace_tboundB(freespace.tboundB);
  end

  vcm.set_boundary_detect(boundary.detect);
  if (boundary.detect == 1) then
    if (freespace.detect == 1) then
      vcm.set_boundary_top(freespace.vboundB);
    else
      vcm.set_boundary_top(boundary.top);
    end
      vcm.set_boundary_bottom(boundary.bottom);
  end
end

function print_time()
  if (enable_timeprinting == 1) then
    if (ball.detect == 1) then
      print ('Ball detected')
    end
    print ('ball detecting time:            '..Tball..'\n')
    if (goalYellow.detect == 1) then
      print ('Goal detected')
    end
    print ('yellow goal detecting time:     '..TgoalYellow..'\n')
    if (enableLine == 1) then
      if (line.detect == 1) then
        print (line.nLines..'lines detected')
      end
      print ('line detecting time:            '..Tline..'\n')
      if (corner.detect == 1) then
        print ('corner detected')
      end
      print ('corner detecting time:          '..Tcorner..'\n')
    end
    if (enableMidfieldLandmark == 1) then
      if (landmarkCyan.detect == 1) then
        print ('landmarkCyan detected')
      end
      print ('cyan landmark detecting time:   '..TlandmarkCyan)
      if (landmarkYellow.detect == 1) then
        print ('landmarkYellow detected')
      end
      print ('yellow landmark detecting time: '..TlandmarkYellow..'\n')
    end
   if (enable_freespace_detection == 1) then
      if (freespace.detect == 1) then
        print ('freespace detected')
      end
      print ('freespace detecting time:       '..Tfreespace..'\n')
      if (boundary.detect == 1) then
        print ('boundary detected')
      end
      print ('boundary detecting time:        '..Tboundary..'\n')
    end
    if (enalbeRobot == 1) then
      print ('robot detecting time:           '..Trobot..'\n')
    end
  end
end

function exit()
end
