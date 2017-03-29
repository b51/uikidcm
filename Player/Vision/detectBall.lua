module(..., package.seeall);

require('Config');      -- For Ball and Goal Size
require('ImageProc');
require('HeadTransform');       -- For Projection
require('Vision');
require('Body');
require('shm');
require('vcm');
require('mcm');
require('Detection');
require('Debug');

-- Define Color
colorOrange = Config.color.orange;
colorYellow = Config.color.yellow;
colorCyan = Config.color.cyan;
colorField = Config.color.field;
colorWhite = Config.color.white;

diameter = Config.vision.ball.diameter;
th_min_color=Config.vision.ball.th_min_color;
th_min_color2=Config.vision.ball.th_min_color2;
th_min_fill_rate=Config.vision.ball.th_min_fill_rate;
th_max_fill_rate=Config.vision.ball.th_max_fill_rate;
th_height_max=Config.vision.ball.th_height_max;
th_ground_boundingbox=Config.vision.ball.th_ground_boundingbox;
th_min_green1=Config.vision.ball.th_min_green1;
th_min_green2=Config.vision.ball.th_min_green2;

check_for_ground = Config.vision.ball.check_for_ground;
check_for_field = Config.vision.ball.check_for_field or 0;
field_margin = Config.vision.ball.field_margin or 0;

-- Define new ball color, need add to Config file
colorBallWhite = 4;
colorBallBlack = 2;
colorBallOthers = 1;

colorBallAll = 7;   --三种颜色值相加

th_min_color_black = 2;
th_min_color_white = 30;
th_min_color_others = 20;

th_max_color_black = 1000/4;  --估计的最大值
th_max_color_white = 3000/4;
th_max_color_others = 1000/4;

th_min_white_fillrate = 0.20;
th_min_others_fillrate = 0.35;
th_min_black_fillrate = 0.01;

th_max_white_fillrate = 0.65;
th_max_others_fillrate = 0.65;
th_max_others_fillrate = 0.2;

th_headAngle = Config.vision.ball.th_headAngle or 30*math.pi/180;

pointProcFlag = {};
infoOfCluster = {};
relationMap = {};
ORIGINAL_BALL_RADIUS = 140;
Dxy = {vector.new({-1, 0}), vector.new({0, 1}), vector.new({1, 0}), vector.new({0, -1})};

function detect(color)
  print('Detect ball');
	
	t = unix.time();	--b51
--  enable_obs_challenge = Config.obs_challenge or 0;
--  if enable_obs_challenge == 1 then
--    colorCount = Vision.colorCount_obs;
--  else
--    colorCount = Vision.ballColorCount;
--  end

  --headAngle = Body.get_head_position();
  headAngle = {Body.get_sensor_headpos()[2],Body.get_sensor_headpos()[1]};	--b51
  --print("headAngle detectball:",headAngle[1]*180/math.pi, headAngle[2]*180/math.pi);
  local ball = {};
  ball.detect = 0;
  local ballWhite = {};
  local ballOthers = {};
  local ballBlack = {};
  ballOthers.propsA = {};
  ballBlack.propsA = {};
  ballBlack.propsA = {};
  ballProbsBBox = {};
  whiteStartCount = 1;
  colorCount = Vision.ballColorCount;

  local ballWhiteProps = {};
  local ballBlackProps = {};
  local ballOthersProps = {};
  --[[
  vcm.add_debug_message(string.format("\nBall: pixel count: %d\n",
	colorCount[color]));
  --]]
  
--  print(string.format("\nBall: pixel count: %d\n",
--	      colorCount[color]));


  -- threshold check on the total number of ball pixels in the image
  --[[
  if (colorCount[color] < th_min_color) then  	
    vcm.add_debug_message("pixel count fail");
    return ball;  	
  end
  --]]

  if (colorCount[colorBallWhite] < th_min_color_white or colorCount[colorBallBlack] < th_min_color_black or colorCount[colorBallOthers] < th_min_color_others) then  	
    vcm.add_debug_message("pixel count fail");
    print('pixel count fail');
    return ball;  	
  end

  -- find connected components of ball pixels
--  if enable_obs_challenge == 1 then
--    ballPropsB = ImageProc.connected_regions_obs(Vision.labelB.data_obs, Vision.labelB.m, 
--                                              Vision.labelB.n, color);
--  else
--    ballPropsB = ImageProc.connected_regions(Vision.labelB.data, Vision.labelB.m,
--                                              Vision.labelB.n, color);
--
    ballWhiteProps = ImageProc.connected_regions(Vision.labelB.data, Vision.labelB.m,
                                                Vision.labelB.n, colorBallWhite);
    ballBlackProps = ImageProc.connected_regions(Vision.labelB.data, Vision.labelB.m,
                                                Vision.labelB.n, colorBallBlack);
    ballOthersProps = ImageProc.connected_regions(Vision.labelB.data, Vision.labelB.m,
                                                 Vision.labelB.n, colorBallOthers);
--  end
--  util.ptable(ballPropsB);
--TODO: horizon cutout
-- ballPropsB = ImageProc.connected_regions(labelB.data, labelB.m, 
--	labelB.n, HeadTransform.get_horizonB(),color);

--  if (#ballPropsB == 0) then return ball; end
  if (#ballWhiteProps == 0 or #ballBlackProps == 0 or #ballOthersProps == 0) then 
    print('ball props zero'); 
    return ball; 
  end

  local ballOthersCount = 1;
  for i = 1, #ballOthersProps do
    if ballOthersProps[i].area < th_max_color_others then
      ballOthers.propsA[ballOthersCount] = Vision.ballBboxStats(colorBallOthers, ballOthersProps[i].boundingBox)
      ballOthersCount = ballOthersCount + 1;
    end
  end

  local ballBlackCount = 1;
  for i = 1, #ballBlackProps do
    if ballBlackProps[i].area < th_max_color_black then
      ballBlack.propsA[ballBlackCount] = Vision.ballBboxStats(colorBallBlack, ballBlackProps[i].boundingBox)
      ballBlackCount = ballBlackCount + 1;
    end
  end


  for i = 1, #ballWhiteProps do
    if ballWhiteProps[i].area > th_max_color_white then
      whiteStartCount = i+1;
    else
      break;
    end
  end

  if whiteStartCount <= #ballWhiteProps then
    for i = whiteStartCount, #ballWhiteProps do
      local z = 1;
      whiteCheckPassed = true;
      ballWhite.propsA = Vision.ballBboxStats(colorBallWhite, ballWhiteProps[i].boundingBox);
      ballWhite.bboxA = Vision.bboxB2A(ballWhiteProps[i].boundingBox);
      local fill_rate_white = ballWhite.propsA.area / Vision.bboxArea(ballWhite.propsA.boundingBox);
      if fill_rate_white > th_max_white_fillrate or fill_rate_white < th_min_white_fillrate then
        whiteCheckPassed = false;
      else
        ballOthersInWhite = Vision.ballBboxStats(colorBallOthers, ballWhiteProps[i].boundingBox);
        if ballOthersInWhite.area < 10 then
          whiteCheckPassed = false;
        else
          for j = 1, #ballOthers.propsA do
            if not region_closed_check(ballWhite.propsA.boundingBox, ballOthers.propsA[j].boundingBox) then
              whiteCheckPassed = false;
            else
              newBbox = enlarge_bbox(ballWhite.propsA.boundingBox, ballOthers.propsA[j].boundingBox);
              ballBlackInWhite = Vision.ballBboxStats(colorBallBlack, newBbox);
              if ballBlackInWhite.area < 3 then
                whiteCheckPassed = false;
              else
                for k = 1, #ballBlack.propsA do
                  if not region_closed_check(newBbox, ballBlack.propsA[k].boundingBox) then
                    whiteCheckPassed = false;
                  else
                    newBbox = enlarge_bbox(newBbox, ballBlack.propsA[k].boundingBox);
                  end -- end black region close check
                end -- end black circle in bbox check
              end -- end black counts in bbox check
            end -- end other region close check
          end -- end of ball other color for circle
        end -- end ball other counts in white check
      end -- end of fill_rate_white check

      if whiteCheckPassed then
        ballProbsBBox[z] = newBbox;
        z = z+1;
      end

    end -- end of whiteRegions connect check
  end -- end white probs pixel counts check
  print('#ballProbsBBox');

-- Check max 5 largest blobs 
--  for i=1,math.min(5,#ballPropsB) do
--  for i=1,math.min(5,#ballProbsBBox) do
  for i=1, #ballProbsBBox do
    vcm.add_debug_message(string.format(
	"Ball: checking blob %d/%d\n",i,#ballPropsB));

    check_passed = true;
--    ball.propsB = ballPropsB[i];
    ball.propsA = Vision.ballColorBboxStats(colorBallAll, ballProbsBBox[i]);
--    ball.bboxA = Vision.bboxB2A(ballPropsB[i].boundingBox);
    ball.bboxA = ballProbsBBox[i];
    local fill_rate = ball.propsA.area / 
	                    Vision.bboxArea(ball.propsA.boundingBox);
    local white_percentage = ball.propsA.whiteArea / ball.propsA.area;
    local others_percentage = ball.propsA.othersArea / ball.propsA.area;
    local black_percentage = ball.propsA.blackArea / ball.propsA.area;

    vcm.add_debug_message(string.format("Area:%d\nFill rate:%2f\n",
       ball.propsA.area,fill_rate));

    if ball.propsA.area < th_min_color2 then
      --Area check
      vcm.add_debug_message("Area check fail\n");
      check_passed = false;
    elseif fill_rate < th_min_fill_rate and fill_rate > th_max_fill_rate then
      --Fill rate check
      vcm.add_debug_message("Fillrate check fail\n");
      check_passed = false;
    else

      if white_percentage < 0.35 or white_percentage > 0.7 
        or others_percentage < 0.35 or others_percentage > 0.7
        or black_percentage < 0.01 or others_percentage > 0.3 then
        vcm.add_debug_message("Color Area check fail\n");
        check_passed = false;
      else

        -- diameter of the area
        dArea = math.sqrt((4/math.pi)*ball.propsA.area);
        -- Find the centroid of the ball
        ballCentroid = ball.propsA.centroid;
        
        --print("ballCentroid :"..ballCentroid[1],ballCentroid[2]);
        
        -- Coordinates of ball
        scale = math.max(dArea/diameter, ball.propsA.axisMajor/diameter);
        v = HeadTransform.coordinatesA(ballCentroid, scale);
        --print("ballv"..v[1],v[2]);	--168
        v_inf = HeadTransform.coordinatesA(ballCentroid,0.1);
        vcm.add_debug_message(string.format(
	"Bal  l v0: %.2f %.2f %.2f\n",v[1],v[2],v[3]));

        if v[3] > th_height_max then
          --Ball height check
          vcm.add_debug_message("Height check fail\n");
          check_passed = false;

        elseif check_for_ground>0 and
          headAngle[2] < th_headAngle then
          -- ground check
          -- is ball cut off at the bottom of the image?
          local vmargin=Vision.labelA.n-ballCentroid[2];
          vcm.add_debug_message("Bottom margin check\n");
          vcm.add_debug_message(string.format(
    	    "labelA height: %d, centroid Y: %d diameter: %.1f\n",
  	    Vision.labelA.n, ballCentroid[2], dArea ));
          --When robot looks down they may fail to pass the green check
          --So increase the bottom margin threshold
          if vmargin > dArea * 2.0 then
            -- bounding box below the ball
            fieldBBox = {};
            fieldBBox[1] = ballCentroid[1] + th_ground_boundingbox[1];
            fieldBBox[2] = ballCentroid[1] + th_ground_boundingbox[2];
            fieldBBox[3] = ballCentroid[2] + .5*dArea 
			  	     + th_ground_boundingbox[3];
            fieldBBox[4] = ballCentroid[2] + .5*dArea 
 			  	     + th_ground_boundingbox[4];
            -- color stats for the bbox
            fieldBBoxStats = ImageProc.color_stats(Vision.labelA.data, 
  	      Vision.labelA.m, Vision.labelA.n, colorField, fieldBBox);
            -- is there green under the ball?
            vcm.add_debug_message(string.format("Green check:%d\n",
	   	     fieldBBoxStats.area));
            if (fieldBBoxStats.area < th_min_green1) then
              -- if there is no field under the ball 
        	    -- it may be because its on a white line
              whiteBBoxStats = ImageProc.color_stats(Vision.labelA.data,
 	        Vision.labelA.m, Vision.labelA.n, colorWhite, fieldBBox);
              if (whiteBBoxStats.area < th_min_green2) then
                vcm.add_debug_message("Green check fail\n");
                check_passed = false;
              end
            end --end white line check
          end --end bottom margin check
        end --End ball height, ground check
      end
    end --End all check

    if check_passed then    
      ballv = {v[1],v[2],0};
--      ballv = {v_inf[1],v_inf[2],0};
      pose=wcm.get_pose();
      posexya=vector.new( {pose.x, pose.y, pose.a} );
      ballGlobal = util.pose_global(ballv,posexya); 
      if check_for_field>0 then
        if math.abs(ballGlobal[1]) > 
   	  Config.world.xLineBoundary + field_margin or
          math.abs(ballGlobal[2]) > 
	  Config.world.yLineBoundary + field_margin then

          vcm.add_debug_message("Field check fail\n");
          check_passed = false;
        end
      end
    end
    if check_passed then
      break;
    end

  end --End loop

  if not check_passed then
    return ball;
  end
  
  --SJ: Projecting ball to flat ground makes large distance error
  --We are using declined plane for projection

  vMag =math.max(0,math.sqrt(v[1]^2+v[2]^2)-0.50);
  bodyTilt = vcm.get_camera_bodyTilt();
--  print("BodyTilt:",bodyTilt*180/math.pi)
  projHeight = vMag * math.tan(10*math.pi/180);


  v=HeadTransform.projectGround(v,diameter/2-projHeight);

  --SJ: we subtract foot offset 
  --bc we use ball.x for kick alignment
  --and the distance from foot is important
  v[1]=v[1]-mcm.get_footX()

  ball_shift = Config.ball_shift or {0,0};
  --Compensate for camera tilt
  v[1]=v[1] + ball_shift[1];
  v[2]=v[2] + ball_shift[2];
  --Ball position ignoring ball size (for distant ball observation)
  v_inf=HeadTransform.projectGround(v_inf,diameter/2);
  v_inf[1]=v_inf[1]-mcm.get_footX()
  
  wcm.set_ball_v_inf({v_inf[1],v_inf[2]});  

  ball.v = v;
  --print("ball.v :"..v[1],v[2]);	--168
  ball.detect = 1;
  ball.r = math.sqrt(ball.v[1]^2 + ball.v[2]^2);
  
  -- How much to update the particle filter
  ball.dr = 0.25*ball.r;
  ball.da = 10*math.pi/180;

  vcm.add_debug_message(string.format(
	"Ball detected\nv: %.2f %.2f %.2f\n",v[1],v[2],v[3]));
--[[
  print(string.format(
	"Ball detected\nv: %.2f %.2f %.2f\n",v[1],v[2],v[3]));
--]]
  return ball;
end

function region_closed_check(bbox1, bbox2)
  if bbox2[1] > bbox1[2] or bbox2[2] < bbox1[1]
    or bbox2[3] > bbox1[4] or bbox2[4] < bbox[3] then
    return false;
  end
  return true;
end

function enlarge_bbox()
  enlargedBbox = vector.new({
    math.min(bbox1[1], bbox2[1]), 
    math.max(bbox1[2], bbox2[2]), 
    math.min(bbox1[3], bbox2[3]),
    math.max(bbox1[4], bbox2[4])
  });
  return enlargedBbox;
end
