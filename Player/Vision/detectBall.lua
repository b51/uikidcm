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

diameter = Config.vision.ball.diameter; -- 0.14
th_min_color=Config.vision.ball.th_min_color; -- 9
th_min_color2=Config.vision.ball.th_min_color2; -- 9
th_max_color2=14000;
--th_min_fill_rate=Config.vision.ball.th_min_fill_rate; -- 0.35
th_min_fill_rate= 0.25
th_max_fill_rate=Config.vision.ball.th_max_fill_rate; -- 0.9
th_min_black_rate=0.01;
th_max_black_rate = 0.5;
th_min_black_area = 3;
max_distance = 4.5;
th_height_max=Config.vision.ball.th_height_max;   -- 0.3
th_height_min = -0.3;
th_ground_boundingbox=Config.vision.ball.th_ground_boundingbox; -- {-10,10,-10,15}
th_min_green1=Config.vision.ball.th_min_green1; -- 0.4
th_min_green2=Config.vision.ball.th_min_green2; -- 0.0555555
th_max_aspect_ratio = 1.7;
th_min_aspect_ratio = 0.5;

ball_check_for_ground = Config.vision.ball.check_for_ground; -- 1
--ball_check_for_ground = 0;
check_for_field = Config.vision.ball.check_for_field or 0; -- 1
field_margin = Config.vision.ball.field_margin or 0; -- 2.0

th_headAngle = Config.vision.ball.th_headAngle or 30*math.pi/180; -- 30 degree

function getCheckBoxWithOffset(target, offset)
	ret = target;
	ret[1] = ret[1] - offset;
	ret[2] = ret[2] + offset;
	ret[3] = ret[3] - offset;
	ret[4] = ret[4] + offset;
	return ret;
end

function detectArbitraryBall()
  local ball = {};
  ball.detect = 0;
	--print("entering arbirary ball detection routine");

  local ballPropsB = ImageProc.connected_ballCandidates(
																													Vision.labelA.dataBall, 
																													Vision.labelA.m, 
																													Vision.labelA.n, 
headAngle[2]+10*math.pi/180
																												);

  if (not ballPropsB or #ballPropsB == 0) then return ball; end

	local minEval = math.huge;
	local minId = 0;

	for i = 1, #ballPropsB do
		
		--print("cntr", ballPropsB[i].blCntr, ballPropsB[i].bkCntr, ballPropsB[i].wtCntr, ballPropsB[i].radiusRate)
		--print("bbox", ballPropsB[i].boundingBox[1], ballPropsB[i].boundingBox[2], ballPropsB[i].boundingBox[3], ballPropsB[i].boundingBox[4])

		local check_passed = true; 
		local totalCntr = ballPropsB[i].blCntr + ballPropsB[i].bkCntr + ballPropsB[i].wtCntr;

		-- calculate the probability from those returned value
		if(ballPropsB[i].radiusRate < 0.5 or totalCntr < 50 ) then
			check_passed = false;
		end
	
		if(check_passed) then
			fillRate = totalCntr/((ballPropsB[i].boundingBox[2]-ballPropsB[i].boundingBox[1]+1)*(ballPropsB[i].boundingBox[4]-ballPropsB[i].boundingBox[3]+1));
			if(fillRate < 0.3) then
				check_passed = false;
			end
		end

		if(check_passed) then
			squareRate = (ballPropsB[i].boundingBox[2]-ballPropsB[i].boundingBox[1]+1)/(ballPropsB[i].boundingBox[4]-ballPropsB[i].boundingBox[3]+1);
			if(squareRate > 1) then
				squareRate = 1/squareRate;
			end
			if (squareRate <0.4) then
                          check_passed = false;
                        elseif(squareRate <0.65 and headAngle[2] > 55*math.pi/180) then
				check_passed = false;
			end
		end 

		if(check_passed) then
			background_check_offset = 2;
			local checkBox = ballPropsB[i].boundingBox;
			checkBox = getCheckBoxWithOffset (checkBox, background_check_offset);
			--print(unpack(checkBox));
			
			statsResult = ImageProc.bounding_field_stats(Vision.labelA.data, Vision.labelA.m, Vision.labelA.n, colorField, checkBox);
			--print("backgroundRatio", statsResult.backgroundRatio)
			if(statsResult.backgroundRatio < 0.5) then
				check_passed = false;
			end
		end

		if(check_passed) then

			Kcolor = 0.2;
			Kradius = 0.2;
			Kground = 0.2;
			Ksquare = 0.2;
			Kfill = 0.2;
			
			--Kcolor =1.5 * math.sqrt((4/math.pi)*totalCntr) / 90;

			local evaluation = Kcolor * ((ballPropsB[i].blCntr/totalCntr - 0.4)^2 + 
					(ballPropsB[i].wtCntr/totalCntr - 0.4)^2 + 
					(ballPropsB[i].bkCntr/totalCntr - 0.2)^2) + 
					Kradius * (ballPropsB[i].radiusRate - 1)^2 +
					Kground * (statsResult.backgroundRatio -1)^2 +
					Kfill*(fillRate -0.75)^2 +
					Ksquare*(squareRate - 1)^2;

			--[[print("Id rad,fill,square,bkg,EV:",i,
                                        ballPropsB[i].radiusRate, 
					fillRate, 
					squareRate, 
					statsResult.backgroundRatio, 
					evaluation
					);]]

			if(evaluation<minEval) then
				minEval = evaluation;
				minId = i;
			end
		end
	end

	if(minId == 0) then
		--print('exiting the test routine')
	  --os.exit()
		return ball;
	end
	--print("best ball fitted is", minEval, minId)

	ball.propsA = {};
	ball.propsA.centroid = {(ballPropsB[minId].boundingBox[1]+ballPropsB[minId].boundingBox[2])/2, (ballPropsB[minId].boundingBox[3]+ballPropsB[minId].boundingBox[4])/2};
	ball.propsA.area = ballPropsB[minId].wtCntr + ballPropsB[minId].blCntr + ballPropsB[minId].bkCntr;
	ball.propsA.axisMajor = math.max(ballPropsB[minId].boundingBox[2]-ballPropsB[minId].boundingBox[1],ballPropsB[minId].boundingBox[4]-ballPropsB[minId].boundingBox[3]);
	ball.propsA.axisMinor = math.min(ballPropsB[minId].boundingBox[2]-ballPropsB[minId].boundingBox[1],ballPropsB[minId].boundingBox[4]-ballPropsB[minId].boundingBox[3]);
	ball.propsA.boundingBox = ballPropsB[minId].boundingBox;

	--print("propsA: ", ball.propsA.area, ball.propsA.axisMajor, ball.propsA.axisMinor)
	--print("centroid: ", unpack(ball.propsA.centroid))

	-- diameter of the area
	local dArea = math.sqrt((4/math.pi)*ball.propsA.area);
	-- Find the centroid of the ball
	local ballCentroid = ball.propsA.centroid;
	-- Coordinates of ball
	local scale = math.max(dArea/diameter, ball.propsA.axisMajor/diameter);

	--print("interface to previous:",dArea, ballCentroid, scale)

	v = HeadTransform.coordinatesA(ballCentroid, scale);
	v_inf = HeadTransform.coordinatesA(ballCentroid,0.1);

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
  ball.detect = 1;
  ball.r = math.sqrt(ball.v[1]^2 + ball.v[2]^2);
  
  -- How much to update the particle filter
  ball.dr = 0.25*ball.r;
  ball.da = 10*math.pi/180;

	t003 = unix.time();

	--print('exiting the test routine')
	--os.exit()

	return ball;

end

function detect(color)
	
	t001 = unix.time();
  colorCount = Vision.colorCount;

  headAngle = {Body.get_sensor_headpos()[2],Body.get_sensor_headpos()[1]};	--b51

	if (color == "arbitrary") then
	--if (true) then
		return detectArbitraryBall();
	end

  local ball = {};
  ball.detect = 0;
  -- threshold check on the total number of ball pixels in the image
  if (colorCount[color] < th_min_color) then  	
    return ball;  	
  end

  -- find connected components of ball pixels
  local ballPropsB = ImageProc.connected_regions(Vision.labelB.data, Vision.labelB.m, Vision.labelB.n, colorWhite);

  if (not ballPropsB or #ballPropsB == 0) then return ball; end

-- Check max 5 largest blobs 
  --print("ballPropsB num = "..#ballPropsB);
  for i=1, #ballPropsB do
    check_passed = true;
    ball.propsB = ballPropsB[i];
    ball.propsA = Vision.bboxStats(colorWhite, ballPropsB[i].boundingBox);
    ball.bboxA = Vision.bboxB2A(ballPropsB[i].boundingBox);
    
    local aspect_ratio = ball.propsA.axisMajor / ball.propsA.axisMinor;
    if (ball.propsA.axisMajor == 0) then aspect_ratio = ball.propsA.axisMajor / 0.00001 end

    local props_black = ImageProc.color_stats(Vision.labelA.data, Vision.labelA.m, Vision.labelA.n, colorOrange, ball.bboxA);
    local black_rate = props_black.area / ball.propsA.area;

    local fill_rate = (ball.propsA.area + props_black.area) / Vision.bboxArea(ball.propsA.boundingBox);

    --print("i = "..i.." fill_rate = "..fill_rate.." area = "..ball.propsA.area)

    if ball.propsA.area > th_max_color2 then  --need check with largest pixel area
      --print(ball.propsA.area.." > th_max_color2");
      check_passed = false;
    elseif ball.propsA.area < th_min_color2 then
      --Area check
      --print(ball.propsA.area.." < th_min_color2");
      check_passed = false;
    elseif fill_rate < th_min_fill_rate then  -- need check fill rate
      --Fill rate check
      --print(fill_rate.." < th_min_fill_rate");
      check_passed = false;
    elseif ball.propsA.boundingBox[4] < HeadTransform.get_horizonA() then
      --print(i.."boudnbox 4: "..ball.propsA.boundingBox[4].." < horizonA".." "..HeadTransform.get_horizonA());
      check_passed = false;
    elseif aspect_ratio > th_max_aspect_ratio then
      --print(i.." > th_max_aspect_ratio");
      check_passed = false;
    elseif aspect_ratio < th_min_aspect_ratio then
      --print(i.." < th_min_aspect_ratio");
      check_passed = false;
    elseif black_rate < th_min_black_rate then
      --print(i.." "..black_rate.." < th_min_black_rate");
      check_passed = false;
    elseif props_black.area < th_min_black_area then
      --print(i.." < th_min_black_area");
      check_passed = false;
    else
      -- diameter of the area
      --print(i.." passed up");
      local dArea = math.sqrt((4/math.pi)*ball.propsA.area);
      -- Find the centroid of the ball
      local ballCentroid = ball.propsA.centroid;
      -- Coordinates of ball
      local scale = math.max(dArea/diameter, ball.propsA.axisMajor/diameter);

      v = HeadTransform.coordinatesA(ballCentroid, scale);
      v_inf = HeadTransform.coordinatesA(ballCentroid,0.1);

      --print(i.." v[3]"..v[3].." ["..th_height_min..", "..th_height_max.."]")
--      if v[3] < th_height_min or v[3] > th_height_max then
      if v[3] > th_height_max then
        --Ball height check
        check_passed = false;
      end

      if check_passed then
        ball_dist_inf = math.sqrt(v_inf[1]*v_inf[1] + v_inf[2]*v_inf[2])
        height_th_inf = th_height_max + ball_dist_inf * math.tan(10*math.pi/180)
        if v_inf[3] > height_th_inf then
           check_passed = false;
        end

        pose=wcm.get_pose();
        posexya=vector.new( {pose.x, pose.y, pose.a} );
        ballGlobal = util.pose_global({v[1],v[2],0},posexya); 
        if ballGlobal[1]>Config.world.xMax * 2.0 or
           ballGlobal[1]<-Config.world.xMax* 2.0 or
           ballGlobal[2]>Config.world.yMax * 2.0 or
           ballGlobal[2]<-Config.world.yMax* 2.0 then
           if (v[1]*v[1] + v[2]*v[2] > max_distance*max_distance) then          
             check_passed = false;
           end
        end

        local ball_dist = math.sqrt(v[1]*v[1] + v[2]*v[2])
        local height_th = th_height_max + ball_dist * math.tan(8*math.pi/180)
        if check_passed and v[3] > 0.3 then
		     check_passed = false
        end

        if check_passed and v[3] > height_th then
          check_passed = false; 
        end     

        if (ball_check_for_ground > 0)  then  -- ground check
          local vmargin=Vision.labelA.n-ballCentroid[2];
          local hmargin=Vision.labelA.m-ballCentroid[1];
          if (ballCentroid[1] > dArea) then
            local fieldBBox_left = {}
            fieldBBox_left[1] = ballCentroid[1] - .5*dArea + th_ground_boundingbox[1];
            fieldBBox_left[2] = ballCentroid[1] - .5*dArea;
            fieldBBox_left[3] = ballCentroid[2] - .5*dArea;
            fieldBBox_left[4]= ballCentroid[2] + .5*dArea;
            local left_area = Vision.bboxArea(fieldBBox_left);
          
            local fieldBBoxStats_left = ImageProc.color_stats(Vision.labelA.data,
                                  Vision.labelA.m, Vision.labelA.n, colorField, fieldBBox_left);
             
            --if (fieldBBoxStats_left.area/left_area < th_min_green1) then
            if (fieldBBoxStats_left.area < 8) then
            --print("a: fieldBBoxStats_left.area "..fieldBBoxStats_left.area.." left_area  "..left_area.." "..fieldBBoxStats_left.area/left_area.."< "..th_min_green1)
				      check_passed = false;
            end
          else
            check_passed = false;
          end

          if (hmargin > dArea or (hmargin > dArea / 2)) and check_passed then 
            local fieldBBox_right = {}
            fieldBBox_right[1] = ballCentroid[1] + .5*dArea;
            fieldBBox_right[2] = ballCentroid[1] + .5*dArea + th_ground_boundingbox[2];
            fieldBBox_right[3] = ballCentroid[2] - .5*dArea;
            fieldBBox_right[4] = ballCentroid[2] + .5*dArea;
            local right_area = Vision.bboxArea(fieldBBox_right);
            local fieldBBoxStats_right = ImageProc.color_stats(Vision.labelA.data,
                                  Vision.labelA.m, Vision.labelA.n, colorField, fieldBBox_right);
             
--            if (fieldBBoxStats_right.area/right_area < th_min_green1) then
            if (fieldBBoxStats_right.area < 8) then
            --print("a: fieldBBoxStats_right.area "..fieldBBoxStats_right.area.." righ_area  "..right_area.." "..fieldBBoxStats_right.area/right_area.."< "..th_min_green1)
              check_passed = false;
            end
          else
            check_passed = false;
          end
            
          if ballCentroid[2] > dArea and check_passed then 
            local fieldBBox_top = {}
            fieldBBox_top[1] = ballCentroid[1] - .5*dArea;
            fieldBBox_top[2] = ballCentroid[1] + .5*dArea;
            fieldBBox_top[3] = ballCentroid[2] - .5*dArea + th_ground_boundingbox[3];
            fieldBBox_top[4] = ballCentroid[2] - .5*dArea;
            local top_green_area = Vision.bboxArea(fieldBBox_top);
         
            local fieldBBoxStats_top = ImageProc.color_stats(Vision.labelA.data, Vision.labelA.m, Vision.labelA.n, colorField, fieldBBox_top);
--            if (fieldBBoxStats_top.area/top_green_area < th_min_green1) then
            if (fieldBBoxStats_top.area < 8) then
            --print("a: fieldBBoxStats_top.area "..fieldBBoxStats_top.area.." top_green_area  "..top_green_area.." "..fieldBBoxStats_top.area/top_green_area.."< "..th_min_green1)
				      check_passed = false;
            end
          else
            check_passed = false;
          end

        end -- End ground check
      end -- End check_pass check
    end --End all check
    if check_passed then break end
  end --End loop

  if not check_passed then
    return ball;
  end
  
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
  ball.detect = 1;
  ball.r = math.sqrt(ball.v[1]^2 + ball.v[2]^2);
  
  -- How much to update the particle filter
  ball.dr = 0.25*ball.r;
  ball.da = 10*math.pi/180;

	t003 = unix.time();
  return ball;
end

