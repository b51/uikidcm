-- Vision Parameters
local color = {};
color.orange = 1;
color.yellow = 2;
color.cyan = 4;
color.field = 8;
color.white = 16;
color.goal_and_line = 18;

local vision = {};
vision.ballColor = color.orange;
vision.goal1Color = color.yellow;
vision.goal2Color = color.cyan;
vision.maxFPS = 30;
vision.scaleB = 4;

-- use this to enable yellow goal in vision
vision.enable_2_yellow_goals =0;
-- use this to enable line detection
vision.enable_line_detection = 1;
-- enable corner detection
vision.enable_corner_detection = 0;
-- use this to enable spot detection
vision.enable_spot_detection = 1;
-- use this to enable midfield landmark detection
vision.enable_midfield_landmark_detection = 0;
-- use this to enable copying images to shm (for colortables, testing)
vision.copy_image_to_shm = 1;
-- use this to enable storing all images
vision.store_all_images = 1;
-- use this to enable storing images where the goal was detected
vision.store_goal_detections = 1;
-- use this to enable storing images where the ball was detected
vision.store_ball_detections = 1;

-- use this to substitute goal check with blue/yellow ball check
vision.use_point_goal = 0;

--vision.enable_robot_detection = 1;
vision.enable_robot_detection = 0;

-- use this to enable freespace detection and occupancy map
vision.enable_freespace_detection = 0;

-- use this to enable obstacle specific colortable
vision.enable_lut_for_obstacle = 0;

-- use this to enable detection print_time
vision.print_time = 1;

----------------------------
--OP specific
----------------------------
-- Use tilted bounding box?
vision.use_tilted_bbox = 0;
-- Subsample main image for monitor?
vision.subsampling = 0;  --1/2 sized image
vision.subsampling2 = 1; --1/4 sized image

--Vision parameter values

vision.ball={};
vision.ball.diameter = 0.10;  --Diameter of the ball in meters.
vision.ball.th_min_color = 20;  --Minimum count of colorCount.
vision.ball.th_min_color2 = 20;  --Minimum area of ball.propsA.area
vision.ball.th_min_fill_rate = 0.35;  --Minimum rate of fill_rate.
vision.ball.th_max_fill_rate =0.9;
vision.ball.th_height_max  = 0.30;  --Maximum height we expect to detect the ball, in the robots Head frame.
vision.ball.th_ground_boundingbox = {-40, 40, -40, 60};
vision.ball.th_min_green1 = 0.4;  --Minimum area of fieldBBoxStats.area
vision.ball.th_min_green2 = 0.055555;  --Minimum area of whiteBBoxStats.area

vision.ball.check_for_ground = 1;

vision.ball.check_for_field = 1;
vision.ball.field_margin = 2.0;

vision.goal={};
vision.goal.th_min_color_count=100;
vision.goal.th_nPostB = 10;
vision.goal.th_min_area = 1000;
vision.goal.th_min_orientation = 60*math.pi/180;
vision.goal.th_min_fill_extent={0.35, 0.65};
vision.goal.th_aspect_ratio={2.5,15};
vision.goal.th_edge_margin= 5;
vision.goal.th_bottom_boundingbox=0.9;
vision.goal.th_ground_boundingbox={-15,15,-15,10};
vision.goal.th_min_green_ratio = 0.2;
vision.goal.th_min_bad_color_ratio = 0.1;
--vision.goal.th_goal_separation = {0.35,2.0};
vision.goal.th_goal_separation = {0.35,3.0}; --FOR OP
vision.goal.th_min_area_unknown_post = 200;

--vision.goal.far_goal_threshold= 3.0; --The range we triangulate
vision.goal.far_goal_threshold= 4.0; --The range we triangulate
--vision.goal.distanceFactorCyan = 1;
--vision.goal.distanceFactorYellow = 1;

--VT field goals
vision.goal.distanceFactor = 1.5;
vision.goal.distanceFactorGoalie = 1;

vision.goal.use_centerpost = 0;
vision.goal.check_for_ground = 1;

--SJ: I added landmark threshold values here
vision.landmark = {};
vision.landmark.min_areaA = 6;
vision.landmark.min_fill_extent = 0.35;
vision.landmark.th_centroid = 20;
vision.landmark.th_arearatio = 4;
vision.landmark.th_distratio = 2;
vision.landmark.th_angle = 45*math.pi/180;

vision.line={};
vision.line.max_width = 10;
vision.line.connect_th = 1.4;
vision.line.lwratio = 1.5;
vision.line.max_gap=0;
vision.line.min_length=10;
vision.line.min_angle_diff = 3;
vision.line.max_angle_diff = 90;

vision.spot={}
vision.spot.min_area = 10;
vision.spot.max_area = 150;
vision.spot.aspect_ratio = 0.40;
vision.spot.ground_boundingbox = {-15,15,-15,15};
vision.spot.ground_th = 0.7;
vision.spot.max_black_rate_B = 0.02;
vision.spot.max_black_rate_A = 0.05; -- should be lowered, needs testing

vision.corner={};
vision.corner.dist_threshold = 100; --10 pixel
vision.corner.length_threshold = 15;
vision.corner.min_center_dist = 1.5;

vision.ball.th_headAngle = 30*math.pi/180;  --Minimum angle of headAngle[2].
vision.use_arbitrary_ball = true;

return {
  color = color,
  vision = vision,
};
