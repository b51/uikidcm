module(..., package.seeall);

require('Config');	-- For Ball and Goal Size
require('ImageProc');
require('HeadTransform');	-- For Projection
require('Body')
require('Vision');

-- Dependency
require('Detection');

-- Define Color
colorOrange = Config.color.orange;
colorYellow = Config.color.yellow;
colorCyan = Config.color.cyan;
colorField = Config.color.field;
colorWhite = Config.color.white;

width_min_in_pixel = 4;
width_max_in_pixel = 70;
connect_th = 0.3;
check_for_ground_whole = 0;

goalSizeThresh = 50;

--this threshold makes sure that the posts don't have more than a certain ratio of their length under the horizon
goalHorizonCheck = 1.0;

--Use tilted boundingbox? (robots with nonzero bodytilt)
use_tilted_bbox = Config.vision.use_tilted_bbox or 0; --0
--Use center post to determine post type (disabled for OP)
use_centerpost=Config.vision.goal.use_centerpost or 0;  --0
--Check the bottom of the post for green
check_for_ground = Config.vision.goal.check_for_ground or 0;
--Min height of goalpost (to reject false positives at the ground)
goal_height_min = Config.vision.goal.height_min or -0.5;

if Config.game.playerID >1  then
  distanceFactor = Config.vision.goal.distanceFactor or 1.0 --1.5
else
  distanceFactor = Config.vision.goal.distanceFactorGoalie or 1 --1
end
	
--Post dimension
postDiameter = Config.world.postDiameter or 0.10;
postHeight = Config.world.goalHeight or 0.80;
goalWidth = Config.world.goalWidth or 1.40;



--------------------------------------------------------------
--Vision threshold values (to support different resolutions)
--------------------------------------------------------------
th_min_color_count=Config.vision.goal.th_min_color_count;
th_min_area = Config.vision.goal.th_min_area; --40
th_nPostB = Config.vision.goal.th_nPostB; --10
th_min_orientation = Config.vision.goal.th_min_orientation; --60*pi/180
th_min_fill_extent = Config.vision.goal.th_min_fill_extent; --{0.35, 0.65}
th_aspect_ratio = Config.vision.goal.th_aspect_ratio; --{2.5, 15}
th_edge_margin = Config.vision.goal.th_edge_margin; --5
th_bottom_boundingbox = Config.vision.goal.th_bottom_boundingbox; --0.9
th_ground_boundingbox = Config.vision.goal.th_ground_boundingbox; --{-15, 15, -15, 10}
th_min_green_ratio = Config.vision.goal.th_min_green_ratio; --0.2
th_min_bad_color_ratio = Config.vision.goal.th_min_bad_color_ratio; --0.1
th_goal_separation = Config.vision.goal.th_goal_separation; --{0.35, 3.0}
th_min_area_unknown_post = Config.vision.goal.th_min_area_unknown_post; --200

function detect(color)
  local goal = {};
  goal.detect = 0;

  local postB;

  tiltAngle=0;
  vcm.set_camera_rollAngle(tiltAngle);

  headPitch = Body.get_sensor_headpos()[1];

  --params: label data; w; h; 
  --optinal params: min_width_in_pixel; max_width_in_pixel; connect_th; max_gap_in_pixel; min_height_in_pixel 
  postB = ImageProc.goal_posts_white(Vision.labelA.data,
	Vision.labelA.m, Vision.labelA.n, headPitch, width_min_in_pixel, width_max_in_pixel, connect_th);

  if (not postB or #postB == 0) then return goal; end
--	Vision.labelA.m, Vision.labelA.n, 25*math.pi/180, width_min_in_pixel, width_max_in_pixel, connect_th);

	--convert to expression in labelB, the scale is supposed to be the same for height and width
	for i = 1, #postB do
		postB[i].area = postB[i].area * Vision.labelB.m * Vision.labelB.n/Vision.labelA.m/Vision.labelA.n;
		postB[i].centroid[1] = postB[i].centroid[1]*Vision.labelB.m/Vision.labelA.m;
		postB[i].centroid[2] = postB[i].centroid[2]*Vision.labelB.m/Vision.labelA.m;
		for j = 1,4 do
			postB[i].boundingBox[j] = postB[i].boundingBox[j]*Vision.labelB.m/Vision.labelA.m
		end

		print(i,postB[i].area,unpack(postB[i].centroid))
		print(unpack(postB[i].boundingBox))
	end

	--print("exiting the detectGoal test routine");
	--os.exit();

  local function compare_post_area(post1, post2)
    return post1.area > post2.area
  end

  if (not postB) then 	
--    vcm.add_debug_message("No post detected\n")
    return goal; 
  end

  table.sort(postB, compare_post_area)

  local npost = 0;
  local ivalidB = {};
  local postA = {};
  vcm.add_debug_message(string.format("Checking %d posts\n",#postB));

  lower_factor = 0.3;

  for i = 1,math.min(#postB, th_nPostB) do
    local valid = true;

    --Check lower part of the goalpost for thickness
    
      postStats = Vision.bboxStats(color, postB[i].boundingBox,scaleBGoal);
      boundingBoxLower={};
      boundingBoxLower[1],boundingBoxLower[2],
      boundingBoxLower[3],boundingBoxLower[4]=
        postB[i].boundingBox[1], postB[i].boundingBox[2],
        postB[i].boundingBox[3], postB[i].boundingBox[4];
      boundingBoxLower[3] = lower_factor * boundingBoxLower[3] + (1 - lower_factor) * boundingBoxLower[4];

    -- size and orientation check
    vcm.add_debug_message(string.format("Area check: %d\n", 
      postStats.area));
    if (postStats.area < th_min_area) then
      vcm.add_debug_message(string.format("Area check fail\n"));
      valid = false;
    end

    if valid then
      local orientation= postStats.orientation - tiltAngle;
        vcm.add_debug_message(string.format("Orientation check: %f\n", 
          180*orientation/math.pi));
      if (math.abs(orientation) < th_min_orientation) then
        vcm.add_debug_message("orientation check fail\n");
        valid = false;
      end
    end
      
    --fill extent check
    if postStats.boundingBox[3] == 0 then
      vcm.add_debug_message(string.format("bbox.x0: %d, bbox.x1: %d, bbox.y0: %d, bbox.y1: %d\n",
      postStats.boundingBox[1], postStats.boundingBox[2], postStats.boundingBox[3], postStats.boundingBox[4]));
    end
    if valid then
	--print(unpack(postStats.boundingBox));
      extent = postStats.area / (postStats.axisMajor * postStats.axisMinor);
      local temp_scale = math.sqrt(postStats.area / (postDiameter*postHeight) );
      local coords = HeadTransform.coordinatesA(postStats.centroid, temp_scale);
      local min_extent = th_min_fill_extent[1]
      if (coords[1] > 2) then
        min_extent = th_min_fill_extent[2]
      end
      if (extent < min_extent) then 
        vcm.add_debug_message(string.format("Fill extent check fail\n"));
        valid = false; 
      end
    end

    --aspect ratio check
    if valid then
      local aspect = postStats.axisMajor/postStats.axisMinor;
      vcm.add_debug_message(string.format("Aspect check: %d\n",aspect));
      if (aspect < th_aspect_ratio[1]) or (aspect > th_aspect_ratio[2]) then 
        vcm.add_debug_message("Aspect check fail\n");
        valid = false; 
      end
    end

    --check edge margin
    if valid then

      local leftPoint= postStats.centroid[1] - 
        postStats.axisMinor/2 * math.abs(math.cos(tiltAngle));
      local rightPoint= postStats.centroid[1] + 
        postStats.axisMinor/2 * math.abs(math.cos(tiltAngle));

      vcm.add_debug_message(string.format(
        "Left and right point: %d / %d\n", leftPoint, rightPoint));

      local margin = math.min(leftPoint,Vision.labelA.m-rightPoint);

      vcm.add_debug_message(string.format("Edge margin check: %d\n",margin));

      if margin<=th_edge_margin then
        vcm.add_debug_message("Edge margin check fail\n");
        valid = false;
      end

    end

    -- horizon check
    -- Andrew added a horizon check for % of the potential post under the horizon
    if valid then
      local horizonA = HeadTransform.get_horizonA();
      local checkpoint = postStats.boundingBox[3];
      local checkpoint_top = postStats.boundingBox[4];
      --gets the length of the post
      local checkpoint_dif = checkpoint_top - checkpoint;
      vcm.add_debug_message(string.format("checkpoint: %d, checkpoint_top: %d, Length: %f \n",checkpoint, checkpoint_top, checkpoint_dif));

      --post can't be too short
      if (checkpoint_dif < goalSizeThresh) then
        vcm.add_debug_message(string.format("Too short: %f < %f \n", checkpoint_dif, goalSizeThresh));
        valid = false;
      end

      --check if the post is appropriately around the horizon
      --if checkpoint > horizonA then
      --  vcm.add_debug_message(string.format("Horizon check failed: %d > %d\n",checkpoint,horizonA));
      --  valid = false;
      --end
      if checkpoint_top < horizonA then
        vcm.add_debug_message(string.format("Horizon top check failed: %d < %d\n",checkpoint_top, horizonA));
        valid = false;
      end
      -- Vision:add_debug_message(string.format("GoalBottom: %f, GoalTop: %f, Horizon: %f \n", checkpoint_top, checkpoint, horizonA));
      -- print(string.format("GoalBottom: %f, GoalTop: %f, Horizon: %f", checkpoint_top, checkpoint, horizonA));

      --proportion of the post underneath the Horizon
      local ratio = (checkpoint_top - horizonA)/checkpoint_dif;
        vcm.add_debug_message(string.format("checkpoint_top: %f, horizonA: %d, checkpoint_dif: %f, ratio: %f\n", 
          checkpoint_top, horizonA, checkpoint_dif, ratio));
      --if too much of the post is under the horizon, then it can't be a post
      --if (ratio > goalHorizonCheck) then
      --  vcm.add_debug_message(string.format("Too much under horizon\n"));
      --  valid = false;
      --end
    end

    -- ground check at whole post to kill lines
    if valid and check_for_ground_whole>0 then
      local bboxA = Vision.bboxB2A(postB[i].boundingBox);
      local width = bboxA[2]-bboxA[1];
      --check two bounding boxes, one on left, one on right;
      local fieldBBoxWholeR = {};
      local fieldBBoxWholeL = {}; 
      fieldBBoxWholeL[1],fieldBBoxWholeL[2],fieldBBoxWholeL[3],fieldBBoxWholeL[4]=
        math.max(bboxA[1]-width*2,0),bboxA[1],bboxA[3],bboxA[4]; 
      fieldBBoxWholeR[1],fieldBBoxWholeR[2],fieldBBoxWholeR[3],fieldBBoxWholeR[4]=
        bboxA[2],math.min(bboxA[2]+width*2,Vision.labelA.m-1),bboxA[3],bboxA[4];
      
      local fieldBBoxWholeStatsLGreen = ImageProc.color_stats(Vision.labelA.data,
        Vision.labelA.m, Vision.labelA.n, colorField,fieldBBoxWholeL, tiltAngle);
      local fieldBBoxWholeStatsLWhite = ImageProc.color_stats(Vision.labelA.data,
        Vision.labelA.m, Vision.labelA.n, colorWhite, fieldBBoxWholeL, tiltAngle);
      local fieldBBoxWholeStatsRGreen = ImageProc.color_stats(Vision. labelA.data,
        Vision.labelA.m, Vision.labelA.n, colorField, fieldBBoxWholeR, tiltAngle);
      local fieldBBoxWholeStatsRWhite = ImageProc.color_stats(Vision. labelA.data,
        Vision.labelA.m, Vision.labelA.n, colorWhite, fieldBBoxWholeR, tiltAngle);
      
      green_ratio_wholeL = (fieldBBoxWholeStatsLGreen.area+fieldBBoxWholeStatsLWhite.area)/
        Vision.bboxArea(fieldBBoxWholeL);
      green_ratio_wholeR = (fieldBBoxWholeStatsRGreen.area+fieldBBoxWholeStatsRWhite.area)/
        Vision.bboxArea(fieldBBoxWholeR);
      
      -- is there to much green near the post?
      if (green_ratio_wholeL>th_max_green_ratio_whole) then
        vcm.add_debug_message(string.format("Left whole check fail: %.2f > %.2f\n",green_ratio_wholeL,th_max_green_ratio_whole));
        valid = false;
      end
      if (green_ratio_wholeR>th_max_green_ratio_whole) then
          vcm.add_debug_message(string.format("Right whole check fail: %.2f > %.2f\n",green_ratio_wholeR,th_max_green_ratio_whole));
          valid = false;
      end
    end

    -- ground check at the bottom of the post
    if valid and check_for_ground>0 then 
      local bboxA = Vision.bboxB2A(postB[i].boundingBox);
      if (bboxA[4] < th_bottom_boundingbox * Vision.labelA.n) then

        -- field bounding box 
        local fieldBBox = {};
        fieldBBox[1] = bboxA[1] + th_ground_boundingbox[1];
        fieldBBox[2] = bboxA[2] + th_ground_boundingbox[2];
        fieldBBox[3] = bboxA[4] + th_ground_boundingbox[3];
        fieldBBox[4] = bboxA[4] + th_ground_boundingbox[4];

        local fieldBBoxStats;
        fieldBBoxStats = ImageProc.color_stats(Vision.labelA.data, 
		Vision.labelA.m,Vision.labelA.n,colorField,fieldBBox,tiltAngle);
        local fieldBBoxArea = Vision.bboxArea(fieldBBox);

	      green_ratio=fieldBBoxStats.area/fieldBBoxArea;
        vcm.add_debug_message(string.format("Green ratio check: %.2f\n",green_ratio));

        -- is there green under the ball?
        if (green_ratio<th_min_green_ratio) then
          vcm.add_debug_message("Green check fail\n");
          valid = false;
        end
      end
    end

    if valid then
    --Height Check
      scale = math.sqrt(postStats.area / (postDiameter*postHeight) );
      v = HeadTransform.coordinatesA(postStats.centroid, scale);
      if v[3] < goal_height_min then
--      vcm.add_debug_message(string.format("Height check fail:%.2f\n",v[3]));
        valid = false; 
      end
    end

    if (valid and npost==1) then
      local dGoal = math.abs(postStats.centroid[1]-postA[1].centroid[1]);
      local dPost = math.max(postA[1].axisMajor, postStats.axisMajor);
      local separation=dGoal/dPost;
      if (separation<th_goal_separation[1]) then
        --p_vision:add_debug_message(string.format("separation check fail:%.2f\n",separation))
        valid = false;
      end
    end

    if (valid) then
      ivalidB[#ivalidB + 1] = i;
      npost = npost + 1;
      postA[npost] = postStats;
    end
    if (npost==2)then
      break
    end

  end

--  vcm.add_debug_message(string.format("Total %d valid posts\n", npost ));

  if (npost < 1) then 
    return goal; 
  end

  goal.propsB = {};
  goal.propsA = {};
  goal.v = {};

  for i = 1,(math.min(npost, 2)) do
    goal.propsB[i] = postB[ivalidB[i]];
    goal.propsA[i] = postA[i];

    scale1 = postA[i].axisMinor / postDiameter;
    scale2 = postA[i].axisMajor / postHeight;
    scale3 = math.sqrt(postA[i].area / (postDiameter*postHeight) );

    if goal.propsB[i].boundingBox[3]<2 then 
      --This post is touching the top, so we shouldn't use the height
--      vcm.add_debug_message("Post touching the top\n");
      scale = math.max(scale1,scale3);
    else
      scale = math.max(scale1,scale2,scale3);
    end


--SJ: goal distance can be noisy, so I added bunch of debug message here
--    v1 = HeadTransform.coordinatesA(postA[i].centroid, scale1);
--    v2 = HeadTransform.coordinatesA(postA[i].centroid, scale2);
--    v3 = HeadTransform.coordinatesA(postA[i].centroid, scale3);
--    vcm.add_debug_message(string.format("Distance by width : %.1f\n",
--	math.sqrt(v1[1]^2+v1[2]^2) ));
--    vcm.add_debug_message(string.format("Distance by height : %.1f\n",
--	math.sqrt(v2[1]^2+v2[2]^2) ));
--    vcm.add_debug_message(string.format("Distance by area : %.1f\n",
--	math.sqrt(v3[1]^2+v3[2]^2) ));
--
--    if scale==scale1 then
--      vcm.add_debug_message("Post distance measured by width\n");
--    elseif scale==scale2 then
--      vcm.add_debug_message("Post distance measured by height\n");
--    else
--      vcm.add_debug_message("Post distance measured by area\n");
--    end

    goal.v[i] = HeadTransform.coordinatesA(postA[i].centroid, scale);

    goal.v[i][1]=goal.v[i][1]*distanceFactor;
    goal.v[i][2]=goal.v[i][2]*distanceFactor;


--    vcm.add_debug_message(string.format("post[%d] = %.2f %.2f %.2f\n",
--  i, goal.v[i][1], goal.v[i][2], goal.v[i][3]));
  end

  if (npost == 2) then
    goal.type = 3; --Two posts
  else
    goal.v[2] = vector.new({0,0,0,0});

    -- look for crossbar:
    local postWidth = postA[1].axisMinor;
    local leftX = postA[1].boundingBox[1]-5*postWidth;
    local rightX = postA[1].boundingBox[2]+5*postWidth;
    local topY = postA[1].boundingBox[3]-5*postWidth;
    local bottomY = postA[1].boundingBox[3]+5*postWidth;
    local bboxA = {leftX, rightX, topY, bottomY};

    local crossbarStats = ImageProc.color_stats(Vision.labelA.data, Vision.labelA.m, Vision.labelA.n, color, bboxA,tiltAngle);
    local dxCrossbar = crossbarStats.centroid[1] - postA[1].centroid[1];
    local crossbar_ratio = dxCrossbar/postWidth; 

--    vcm.add_debug_message(string.format(
--  "Crossbar stat: %.2f\n",crossbar_ratio));

    --If the post touches the top, it should be a unknown post
    if goal.propsB[1].boundingBox[3]<3 then --touching the top
      dxCrossbar = 0; --Should be unknown post
    end

    if (math.abs(dxCrossbar) > 0.6*postWidth) then
      if (dxCrossbar > 0) then
        if use_centerpost>0 then
          goal.type = 1;  -- left post
        else
          goal.type = 0;  -- unknown post
        end
      else
        if use_centerpost>0 then
          goal.type = 2;  -- right post
        else
          goal.type = 0;  -- unknown post
        end
      end
    else
      -- unknown post
      goal.type = 0;
        -- eliminate small posts without cross bars
--      vcm.add_debug_message(string.format(
--  "Unknown single post size check:%d\n",postA[1].area));
      
      if (postA[1].area < th_min_area_unknown_post) then
--        vcm.add_debug_message("Post size too small");
        return goal;
      end

    end
  end
  
-- added for test_vision.m
  if Config.vision.copy_image_to_shm then
      vcm.set_goal_postBoundingBox1(postB[ivalidB[1]].boundingBox);
      vcm.set_goal_postCentroid1({postA[1].centroid[1],postA[1].centroid[2]});
      vcm.set_goal_postAxis1({postA[1].axisMajor,postA[1].axisMinor});
      vcm.set_goal_postOrientation1(postA[1].orientation);
      if npost == 2 then
        vcm.set_goal_postBoundingBox2(postB[ivalidB[2]].boundingBox);
        vcm.set_goal_postCentroid2({postA[2].centroid[1],postA[2].centroid[2]});
        vcm.set_goal_postAxis2({postA[2].axisMajor,postA[2].axisMinor});
        vcm.set_goal_postOrientation2(postA[2].orientation);
      else
        vcm.set_goal_postBoundingBox2({0,0,0,0});
      end
  end

--  if goal.type==0 then
--    vcm.add_debug_message(string.format("Unknown single post detected\n"));
--  elseif goal.type==1 then
--    vcm.add_debug_message(string.format("Left post detected\n"));
--  elseif goal.type==2 then
--    vcm.add_debug_message(string.format("Right post detected\n"));
--  elseif goal.type==3 then
--    vcm.add_debug_message(string.format("Two posts detected\n"));
--  end

  goal.detect = 1;
  return goal;
end
