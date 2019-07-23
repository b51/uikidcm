local Config = require('Config') -- For Ball and Goal Size
local HeadTransform = require('HeadTransform') -- For Projection
local Body = require('Body')
local vcm = require('vcm')
local unix = require('unix')
local Camera = require('Camera')

-- Dependency
local DLDetection = require('DLDetection')
local detectBall = require('detectBall')
local detectGoal = require('detectGoal')
--[[
require('detectLine');
require('detectCorner');
if not string.find(Config.platform.name,'Nao') then
  require('detectLandmarks'); -- for NSL
  require('detectLandmarks2'); -- for NSL
end
require('detectSpot');
require('detectFreespace');
require('detectBoundary');

--for quick test
require('detectRobot');
--]]

-- Define Color
-- TODO(b51): remove these color settings
local colorYellow_ = Config.color.yellow
local colorCyan_ = Config.color.cyan
local colorField_ = Config.color.field
local colorWhite_ = Config.color.white
local colorGoalAndLine_ = Config.color.goal_and_line

local use_multi_landmark_ = Config.vision.use_multi_landmark or 0

local enableLine_ = Config.vision.enable_line_detection
local enableCorner_ = Config.vision.enable_corner_detection
local enableSpot_ = Config.vision.enable_spot_detection
local enable_freespace_detection_ = Config.vision.enable_freespace_detection or 0
local enableBoundary_ = Config.vision.enable_visible_boundary or 0
local enableRobot_ = Config.vision.enable_robot_detection or 0
local yellowGoals_ = Config.world.use_same_colored_goal or 0 -- Config.vision.enable_2_yellow_goals or 0;

local enable_timeprinting_ = Config.vision.print_time

local tstart_ = unix.time()
local Tdetection_ = 0

local camera_ = {}
camera_.width = Camera.get_width()
camera_.height = Camera.get_height()
-- net
local net_ = {}
net_.width = Config.net.width
net_.height = Config.net.height
net_.ratio_fixed = Config.net.ratio_fixed
net_.prototxt = Config.net.prototxt
net_.model = Config.net.model
net_.object_thresh = Config.net.object_thresh
net_.nms_thresh = Config.net.nms_thresh
net_.hier_thresh = Config.net.hier_thresh

local ball_ = {}
local goal_ = {}
local landmarkYellow_ = {}
local landmarkCyan_ = {}
-- TODO(b51): Detect line use deep learning, like lane line on road.
--            Detect robot use 3d boundingbox, like car detection in autodrive
local line_ = {}
local corner_ = {}
local spot_ = {}
local obstacle_ = {}
local freespace_ = {}
local boundary_ = {}

local update_shm = function()
  vcm.set_ball_detect(ball_.detect)
  if (ball_.detect == 1) then
    vcm.set_ball_score(ball_.score)
    vcm.set_ball_x(ball_.x)
    vcm.set_ball_y(ball_.y)
    vcm.set_ball_w(ball_.w)
    vcm.set_ball_h(ball_.h)
    vcm.set_ball_v(ball_.v)
    vcm.set_ball_r(ball_.r)
    vcm.set_ball_dr(ball_.dr)
    vcm.set_ball_da(ball_.da)
  end

  vcm.set_goal_detect(goal_.detect)
  if (goal_.detect == 1) then
    vcm.set_goal_color(colorCyan_)
    vcm.set_goal_type(goal_.type)
    vcm.set_goal_v1(goal_.v[1])
    vcm.set_goal_v2(goal_.v[2])
  end

  vcm.set_line_detect(line_.detect)
  if (line_.detect == 1) then
    local v1x = vector.zeros(12)
    local v1y = vector.zeros(12)
    local v2x = vector.zeros(12)
    local v2y = vector.zeros(12)
    local real_length = vector.zeros(12)
    local endpoint11 = vector.zeros(12)
    local endpoint12 = vector.zeros(12)
    local endpoint21 = vector.zeros(12)
    local endpoint22 = vector.zeros(12)
    local xMean = vector.zeros(12)
    local yMean = vector.zeros(12)

    local max_length = 0
    local max_real_length = 0
    local max_index = 1

    for i = 1, line_.nLines do
      v1x[i] = line_.v[i][1][1]
      v1y[i] = line_.v[i][1][2]
      v2x[i] = line_.v[i][2][1]
      v2y[i] = line_.v[i][2][2]
      real_length[i] = math.sqrt((v2x[i] - v1x[i]) ^ 2 + (v2y[i] - v1y[i]) ^ 2)
      -- x0 x1 y0 y1
      endpoint11[i] = line_.endpoint[i][1]
      endpoint12[i] = line_.endpoint[i][3]
      endpoint21[i] = line_.endpoint[i][2]
      endpoint22[i] = line_.endpoint[i][4]
      xMean[i] = line_.meanpoint[i][1]
      yMean[i] = line_.meanpoint[i][2]
      if max_length < real_length[i] then
        max_length = real_length[i]
        max_index = i
      end
    end

    -- TODO: check line length
    vcm.set_line_v1x(v1x)
    vcm.set_line_v1y(v1y)
    vcm.set_line_v2x(v2x)
    vcm.set_line_v2y(v2y)
    vcm.set_line_real_length(real_length)
    vcm.set_line_endpoint11(endpoint11)
    vcm.set_line_endpoint12(endpoint12)
    vcm.set_line_endpoint21(endpoint21)
    vcm.set_line_endpoint22(endpoint22)
    vcm.set_line_xMean(xMean)
    vcm.set_line_yMean(yMean)

    local max_lengthB = math.sqrt(
                            (endpoint11[max_index] - endpoint21[max_index]) ^ 2 +
                                (endpoint12[max_index] - endpoint22[max_index]) ^ 2)
    local mean_v = {
      (v1x[max_index] + v2x[max_index]) / 2,
      (v1y[max_index] + v2y[max_index]) / 2,
      0,
      1,
    }

    vcm.set_line_v(mean_v)
    vcm.set_line_angle(line_.angle[max_index])
    vcm.set_line_nLines(line_.nLines)
    max_real_length = real_length[max_index]
    vcm.set_line_lengthB(max_real_length)
  end

  vcm.set_corner_detect(corner_.detect)
  if (corner_.detect == 1) then
    vcm.set_corner_type(corner_.type)
    vcm.set_corner_vc0(corner_.vc0)
    vcm.set_corner_v10(corner_.v10)
    vcm.set_corner_v20(corner_.v20)
    vcm.set_corner_v(corner_.v)
    vcm.set_corner_v1(corner_.v1)
    vcm.set_corner_v2(corner_.v2)
  end

  vcm.set_spot_detect(spot_.detect)
  if (spot_.detect == 1) then
    vcm.set_spot_v(spot_.v)
    vcm.set_spot_bboxB(spot_.bboxB)
    vcm.set_spot_color(colorWhite_)
  end

  vcm.set_freespace_detect(freespace_.detect)
  if (freespace_.detect == 1) then
    vcm.set_freespace_block(freespace_.block)
    vcm.set_freespace_nCol(freespace_.nCol)
    vcm.set_freespace_nRow(freespace_.nRow)
    vcm.set_freespace_vboundB(freespace_.vboundB)
    vcm.set_freespace_pboundB(freespace_.pboundB)
    vcm.set_freespace_tboundB(freespace_.tboundB)
  end

  vcm.set_boundary_detect(boundary_.detect)
  if (boundary_.detect == 1) then
    if (freespace_.detect == 1) then
      vcm.set_boundary_top(freespace_.vboundB)
    else
      vcm.set_boundary_top(boundary_.top)
    end
    vcm.set_boundary_bottom(boundary_.bottom)
  end
end

local entry = function()
  -- Initiate Detection
  ball_.detect = 0
  goal_.detect = 0
  landmarkYellow_.detect = 0
  landmarkCyan_.detect = 0
  line_.detect = 0
  corner_.detect = 0
  spot_.detect = 0
  obstacle_.detect = 0
  freespace_.detect = 0
  boundary_.detect = 0

  DLDetection.detector_yolo_init(net_.prototxt,
                                 net_.model,
                                 net_.object_thresh,
                                 net_.nms_thresh,
                                 net_.hier_thresh)
end

local update = function()
  -- ball detector
  tstart_ = unix.time()
  local show_image = 0
  -- bboxes_detect return values includes:
  --      frame_id,   image frame_id, increase by one
  --      score,      score of probabilities
  --      x, y, w, h, bounding box
  local detection = DLDetection.bboxes_detect(vcm.get_image_rzdrgb(),
                                              camera_.width,
                                              camera_.height,
                                              net_.width,
                                              net_.height,
                                              show_image)
  Tdetection_ = unix.time() - tstart_
  --[[
  print("DLDetection time: "..Tdetection_);
  for k, v in pairs(detection) do
    print(k..":")
    for m, n in pairs(v) do
      print("    "..m..":")
      for o, p in pairs(n) do
        print("        "..o..": "..p)
      end
    end
  end
  --]]

  ball_ = detectBall.detect(detection.balls)
  --[[
  for k, v in pairs(ball_) do
    print(k.." : ", v)
  end
  --]]
  goal_ = detectGoal.detect(detection.posts)
  --[[
  for k, v in pairs(goal_) do
    print(k.." : ", v)
  end
  --]]

  --[[
  -- line detection
  if enableLine_ == 1 then
    tstart_ = unix.time();
    line_ = detectLine.detect();
    Tline = unix.time() - tstart_;
    if enableCorner_ == 1 then
      corner_ = detectCorner.detect(line_);
      Tcorner = unix.time() - Tline - tstart_;
    end
  end

  -- spot detection
  if enableSpot_ == 1 then
    spot_ = detectSpot.detect();
  end

  -- midfield landmark detection
  if not string.find(Config.platform.name,'Nao') then
   landmarkCyan_ = 0;
   landmarkYellow_ = 0;
   if enableMidfieldLandmark_ == 1 then
     if use_multi_landmark_ == 1 then
       landmarkCyan_ = detectLandmarks2.detect(colorCyan_,colorYellow_);
       landmarkYellow_ = detectLandmarks2.detect(colorYellow_,colorCyan_);
     else
       landmarkCyan_ = detectLandmarks.detect(colorCyan_,colorYellow_);
       landmarkYellow_ = detectLandmarks.detect(colorYellow_,colorCyan_);
     end
   end
  end

  if enable_freespace_detection_ ==1 then
    tstart_ = unix.time();
    freespace_ = detectFreespace.detect(colorField_);
    Tfreespace = unix.time() - tstart_;
    boundary_ = detectBoundary.detect();
    Tboundary = unix.time() - Tfreespace - tstart_;
  end

  -- Global robot detection
  if enableRobot_ ==1 then
    tstart_ = unix.time();
    detectRobot.detect();
    Trobot = unix.time() - tstart_;
  end
  --]]

  update_shm()
end

local exit = function()
end

local print_time = function()
  if (enable_timeprinting_ == 1) then
    print('objects detection time:           ' .. Tdetection_ .. '\n')
  end
end

return {
  entry = entry,
  update = update,
  exit = exit,
  update_shm = update_shm,
  print_time = print_time,
}

