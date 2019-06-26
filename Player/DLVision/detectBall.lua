module(..., package.seeall);

require('Config');      -- For Ball and Goal Size
require('ImageProc');
require('HeadTransform');       -- For Projection
require('Body');
require('shm');
require('vcm');
require('mcm');
require('Detection');
require('Debug');

diameter = Config.vision.ball.diameter; -- 0.14
max_distance = 4.5;
th_height_max=Config.vision.ball.th_height_max;   -- 0.3
th_height_min = -0.3;
th_ground_boundingbox=Config.vision.ball.th_ground_boundingbox; -- {-10,10,-10,15}

ball_check_for_ground = Config.vision.ball.check_for_ground; -- 1
check_for_field = Config.vision.ball.check_for_field or 0; -- 1
field_margin = Config.vision.ball.field_margin or 0; -- 2.0

th_headAngle = Config.vision.ball.th_headAngle or 30*math.pi/180; -- 30 degree

function detect(dballs)
  local balls = dballs
  local ball = {}
  ball.detect = 0;

  if (not balls or #balls == 0) then
    return ball
  end
  local function compare_ball_score(ball1, ball2)
    return ball1.score > ball2.score
  end
  table.sort(balls, compare_ball_score)

  -- {yaw, pitch}
  headAngle = {Body.get_sensor_headpos()[2], Body.get_sensor_headpos()[1]};	--b51
  for i = 1, #balls do
    local check_passed = true;
    -- Find the centroid of the ball
    local ballCentroid = {balls[i].x + balls[i].w / 2, balls[i].y + balls[i].h / 2};
    -- Coordinates of ball
    local scale = math.max(balls[i].w/diameter, balls[i].h/diameter);

    v = HeadTransform.coordinatesA(ballCentroid, scale);
    v_inf = HeadTransform.coordinatesA(ballCentroid,0.1);

    -- TODO(b51) Should keep height check? Tests needed
    --if v[3] > th_height_max then
    --  --Ball height check
    --  check_passed = false;
    --end

    if check_passed then
      ball_dist_inf = math.sqrt(v_inf[1]*v_inf[1] + v_inf[2]*v_inf[2])
      height_th_inf = th_height_max + ball_dist_inf * math.tan(10*math.pi/180)
      if v_inf[3] > height_th_inf then
        print("a, check "..i.."th ball"..v_inf[3]);
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
          print("b, check "..i.."th ball"..max_distance);
          check_passed = false;
        end
      end

      local ball_dist = math.sqrt(v[1]*v[1] + v[2]*v[2])
      local height_th = th_height_max + ball_dist * math.tan(8*math.pi/180)

      --if check_passed and v[3] > height_th then
      --  print("c, check "..i.."th ball"..v[3]);
      --  check_passed = false;
      --end

    end -- End check_pass check

    if check_passed then
      balls[i].detect = 1;
      ball = balls[i];
      break;
    end
  end -- End for #balls
  if ball.detect == 0 then
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
  ball.r = math.sqrt(ball.v[1]^2 + ball.v[2]^2);

  -- How much to update the particle filter
  ball.dr = 0.25*ball.r;
  ball.da = 10*math.pi/180;

  return ball;
end
