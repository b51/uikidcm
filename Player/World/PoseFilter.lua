module(..., package.seeall);

require('Config');
require('vector');
require('vcm')
require('util')

n = Config.world.n;
xLineBoundary = Config.world.xLineBoundary;
yLineBoundary = Config.world.yLineBoundary;
xMax = Config.world.xMax;
yMax = Config.world.yMax;

goalWidth = Config.world.goalWidth;
postYellow = Config.world.postYellow;
postCyan = Config.world.postCyan;
landmarkYellow = Config.world.landmarkYellow;
landmarkCyan = Config.world.landmarkCyan;
spot = Config.world.spot;
ballYellow = Config.world.ballYellow;
ballCyan = Config.world.ballCyan;
landmarkYellow = Config.world.landmarkYellow;
landmarkCyan = Config.world.landmarkCyan;
Lcorner = Config.world.Lcorner;

--Are we using same colored goals?
use_same_colored_goal=Config.world.use_same_colored_goal or 0;

--Triangulation method selection
use_new_goalposts= Config.world.use_new_goalposts or 0;

--For single-colored goalposts
postUnified = {postYellow[1],postYellow[2],postCyan[1],postCyan[2]};
postLeft={postYellow[1],postCyan[1]}
postRight={postYellow[2],postCyan[2]}

rGoalFilter = Config.world.rGoalFilter;
aGoalFilter = Config.world.aGoalFilter;
rPostFilter = Config.world.rPostFilter;
aPostFilter = Config.world.aPostFilter;
rKnownGoalFilter = Config.world.rKnownGoalFilter or Config.world.rGoalFilter;
aKnownGoalFilter = Config.world.aKnownGoalFilter or Config.world.aGoalFilter;
rKnownPostFilter = Config.world.rKnownPostFilter or Config.world.rPostFilter;
aKnownPostFilter = Config.world.aKnownPostFilter or Config.world.aPostFilter;
rUnknownGoalFilter = Config.world.rUnknownGoalFilter or Config.world.rGoalFilter;
aUnknownGoalFilter = Config.world.aUnknownGoalFilter or Config.world.aGoalFilter;
rUnknownPostFilter = Config.world.rUnknownPostFilter or Config.world.rPostFilter;
aUnknownPostFilter = Config.world.aUnknownPostFilter or Config.world.aPostFilter;

rLandmarkFilter = Config.world.rLandmarkFilter;
aLandmarkFilter = Config.world.aLandmarkFilter;

rCornerFilter = Config.world.rCornerFilter;
aCornerFilter = Config.world.aCornerFilter;

aImuYawFilter = Config.world.aImuYawFilter;

xp = .5*xMax*vector.new(util.randn(n));
yp = .5*yMax*vector.new(util.randn(n));
ap = 2*math.pi*vector.new(util.randu(n));
wp = vector.zeros(n);

corner_lut_a = {};
corner_lut_r = {};
goalAngleThres = Config.world.imuGoal_angleThres or 30*math.pi/180;

function corner_init()
  local x0 = -3.05;
  local y0 = -2.05;

  for ix = 1,60 do
    x = x0 + ix*.1;
    corner_lut_a[ix] = {};
    corner_lut_r[ix] = {};
	for iy = 1,40 do
      y = y0 + iy*.1;
      corner_lut_a[ix][iy] = vector.zeros(#Lcorner);
      corner_lut_r[ix][iy] = vector.zeros(#Lcorner);
      for ipos = 1,#Lcorner do
        dx = Lcorner[ipos][1]-x;
        dy = Lcorner[ipos][2]-y;
        corner_lut_r[ix][iy][ipos] = math.sqrt(dx^2+dy^2);
        corner_lut_a[ix][iy][ipos] = math.atan2(dy,dx);
      end
    end
  end
end
function imuGoal(gtype, vgoal, imuYaw)
   -- given a goal detection
   --    determine if it is the yellow or cyan goal
   --
   -- gtype:   goal detection type (0 - unkown, 1 - left post, 2 - right post, 3 - both posts)
   --             for types (0,1,2) only the first pose of vgoal is set
   -- vgoal:   goal post poses, {(x,y,a), (x,y,a)} relative to the robot
   -- return:  0 - unknown
   --         +1 - cyan
   --         -1 - yellow
   -- angle of goal from the robot
   local post1 = vgoal[1];
   local post2 = vgoal[2];
   local agoal = math.atan2(post1[2], post1[1]);
   if (gtype == 3) then
      -- if both posts were detected then use the angle between the two
      agoal = util.mod_angle(post1[3] + 0.5 * util.mod_angle(math.atan2(post2[2], post2[1]) - post2[3]));
   end
   -- angle of goal in world
   agoal = util.mod_angle(agoal + imuYaw);
   -- agoal=0 -> yellow;  agoal=pi -> cyan
   if (math.abs(agoal) < goalAngleThres) then
      -- the goal is yellow
--      print('------------------ detected goal is the yellow goal ------------------');
      return -1;
   elseif (math.abs(mod_angle(math.pi - agoal)) < goalAngleThres) then
      -- the goal is cyan
--      print('++++++++++++++++++ detected goal is the cyan goal ++++++++++++++++++');
      return 1;
   else
      -- the detected goal posts and goalie do not correlate well
--      print('==================       detected goal is unknown      ==================');
      return 0;
   end
   -- if we make it this far then we do not know which goal it is
   return 0;
end

function initialize(p0, dp)
  p0 = p0 or {0, 0, 0};
  dp = dp or {.5*xMax, .5*yMax, 2*math.pi};

  xp = p0[1]*vector.ones(n) + dp[1]*(vector.new(util.randn(n))-0.5*vector.ones(n));
  yp = p0[2]*vector.ones(n) + dp[2]*(vector.new(util.randn(n))-0.5*vector.ones(n));
  ap = p0[3]*vector.ones(n) + dp[3]*(vector.new(util.randu(n))-0.5*vector.ones(n));
  wp = vector.zeros(n);
end

function initialize_manual_placement(p0, dp)
  p0 = p0 or {0, 0, 0};
  dp = dp or {.5*xLineBoundary, .5*yLineBoundary, 2*math.pi};

  print('re-init partcles for manual placement');
  ap = math.atan2(wcm.get_goal_attack()[2],wcm.get_goal_attack()[1])*vector.ones(n);
  xp = wcm.get_goal_defend()[1]/2*vector.ones(n);
  yp = p0[2]*vector.ones(n) + dp[2]*(vector.new(util.randn(n))-0.5*vector.ones(n));
  wp = vector.zeros(n);
end

function initialize_unified(p0,p1,dp)
  --Particle initialization for the same-colored goalpost
  --Half of the particles at p0
  --Half of the particles at p1
  p0 = p0 or {0, 0, 0};
  p1 = p1 or {0, 0, 0};
  --Low spread
  dp = dp or {.15*xMax, .15*yMax, math.pi/6};

  for i=1,n/2 do
    xp[i]=p0[1]+dp[1]*(math.random()-.5);
    yp[i]=p0[2]+dp[2]*(math.random()-.5);
    ap[i]=p0[3]+dp[3]*(math.random()-.5);

    xp[i+n/2]=p1[1]+dp[1]*(math.random()-.5);
    yp[i+n/2]=p1[2]+dp[2]*(math.random()-.5);
    ap[i+n/2]=p1[3]+dp[3]*(math.random()-.5);
  end
  wp = vector.zeros(n);
end

function initialize_heading(aGoal)
  --Particle initialization at bodySet
  --When bodySet, all players should face opponents' goal
  --So reduce weight of  particles that faces our goal
  print('init_heading particles');
  dp = dp or {.15*xMax, .15*yMax, math.pi/6};
  ap = aGoal*vector.ones(n) + dp[3]*vector.new(util.randu(n));
  wp = vector.zeros(n);
end

function reset_heading()
  ap = 2*math.pi*vector.new(util.randu(n));
  wp = vector.zeros(n);
end

function get_pose()
  local wmax, imax = max(wp);
  return xp[imax], yp[imax], mod_angle(ap[imax]);
end

function get_sv(x0, y0, a0)
  -- weighted sample variance of current particles
  local xs = 0.0;
  local ys = 0.0;
  local as = 0.0;
  local ws = 0.0001;

  for i = 1,n do
    local dx = x0 - xp[i];
    local dy = y0 - yp[i];
    local da = mod_angle(a0 - ap[i]);
    xs = xs + wp[i]*dx^2;
    ys = ys + wp[i]*dy^2;
    as = as + wp[i]*da^2;
    ws = ws + wp[i];
  end

  return math.sqrt(xs)/ws, math.sqrt(ys)/ws, math.sqrt(as)/ws;
end

function landmark_ra(xlandmark, ylandmark)
  local r = vector.zeros(n);
  local a = vector.zeros(n);
  for i = 1,n do
    local dx = xlandmark - xp[i];
    local dy = ylandmark - yp[i];
    r[i] = math.sqrt(dx^2 + dy^2);
    a[i] = math.atan2(dy, dx) - ap[i];
  end
  return r, a;
end

function landmark_observation(pos, v, rLandmarkFilter, aLandmarkFilter)
  local r = math.sqrt(v[1]^2 + v[2]^2);
  local a = math.atan2(v[2], v[1]);
  local rSigma = .15*r + 0.10;
  local aSigma = 5*math.pi/180;
  local rFilter = rLandmarkFilter or 0.02;
  local aFilter = aLandmarkFilter or 0.04;

  --Calculate best matching landmark pos to each particle
  local dxp = {};
  local dyp = {};
  local dap = {};
  for ip = 1,n do
    local dx = {};
    local dy = {};
    local dr = {};
    local da = {};
    local err = {};
    for ipos = 1,#pos do
      dx[ipos] = pos[ipos][1] - xp[ip];
      dy[ipos] = pos[ipos][2] - yp[ip];
      dr[ipos] = math.sqrt(dx[ipos]^2 + dy[ipos]^2) - r;
      da[ipos] = mod_angle(math.atan2(dy[ipos],dx[ipos]) - (ap[ip] + a));
      err[ipos] = (dr[ipos]/rSigma)^2 + (da[ipos]/aSigma)^2;
    end
    local errMin, imin = min(err);

    --Update particle weights:
    wp[ip] = wp[ip] - errMin;

    dxp[ip] = dx[imin];
    dyp[ip] = dy[imin];
    dap[ip] = da[imin];
  end
  --Filter toward best matching landmark position:
  --print("&&&&&&&&&&&&&&&&&&&&&&&&&");
  for ip = 1,n do
--  print(string.format("%d %.1f %.1f %.1f %.1f %.1f %.1f",ip,xp[ip],yp[ip],ap[ip],dxp[ip],dyp[ip],dap[ip]));
--  print(string.format("%d %.1f %.1f %.1f",ip,xp[ip],yp[ip],ap[ip]));
--  print(string.format("%.1f %.1f %.1f",dap[ip],dyp[ip],dxp[ip]));
    xp[ip] = xp[ip] + rFilter * (dxp[ip] - r * math.cos(ap[ip] + a));
    yp[ip] = yp[ip] + rFilter * (dyp[ip] - r * math.sin(ap[ip] + a));
    ap[ip] = ap[ip] + aFilter * dap[ip];

    -- check boundary
    xp[ip] = math.min(xMax, math.max(-xMax, xp[ip]));
    yp[ip] = math.min(yMax, math.max(-yMax, yp[ip]));
  end
end

function corner_observation(v,rCornerFilter,aCornerFilter)
  local r = math.sqrt(v[1]^2 + v[2]^2);
  local a = math.atan2(v[2], v[1]);
  local rSigma = .15*r + 0.10;
  local aSigma = 5*math.pi/180;
  local rFilter = rCornerFilter or 0.02;
  local aFilter = aCornerFilter or 0.04;

  --Calculate best matching landmark pos to each particle
  for ip = 1,n do
    local dr = {};
    local da = {};
    local err = {};
    local ix = math.floor((xp[ip]+3)*10)+1;
    local iy = math.floor((yp[ip]+3)*10)+1;
    ix = math.min(60, math.max(ix, 1));
    iy = math.min(40, math.max(iy, 1));
    for ipos = 1,#Lcorner do
      dr[ipos] = corner_lut_r[ix][iy][ipos] - r;
      da[ipos] = mod_angle(corner_lut_a[ix][iy][ipos] - (a + ap[ip]));
      err[ipos] = (dr[ipos]/rSigma)^2 + (da[ipos]/aSigma)^2;
    end
    local errMin, imin = min(err);

    --Update particle weights:
    xp[ip] = xp[ip] + rFilter * (Lcorner[imin][1] - xp[ip] - r * math.cos(ap[ip] + a));
    yp[ip] = yp[ip] + rFilter * (Lcorner[imin][2] - yp[ip] - r * math.sin(ap[ip] + a));
    ap[ip] = ap[ip] + aFilter * da[imin];
    wp[ip] = wp[ip] - errMin;

    -- check boundary
    xp[ip] = math.min(xMax, math.max(-xMax, xp[ip]));
    yp[ip] = math.min(yMax, math.max(-yMax, yp[ip]));
  end
end

---------------------------------------------------------------------------
-- Now we have two ambiguous goals to check
-- So we separate the triangulation part and the update part
---------------------------------------------------------------------------

function triangulate(pos,v)
  --Based on old code

  -- Use angle between posts (most accurate)
  -- as well as combination of post distances to triangulate
  local aPost = {};
  aPost[1] = math.atan2(v[1][2], v[1][1]);
  aPost[2] = math.atan2(v[2][2], v[2][1]);
  local daPost = mod_angle(aPost[1]-aPost[2]);

  -- Radius of circumscribing circle
  local sa = math.sin(math.abs(daPost));
  local ca = math.cos(daPost);
  local rCircumscribe = goalWidth/(2*sa);

  -- Post distances
  local d2Post = {};
  d2Post[1] = v[1][1]^2 + v[1][2]^2;
  d2Post[2] = v[2][1]^2 + v[2][2]^2;
  local ignore, iMin = min(d2Post);

  -- Position relative to center of goal:
  local sumD2 = d2Post[1] + d2Post[2];
  local dGoal = math.sqrt(.5*sumD2);
  local dx = (sumD2 - goalWidth^2)/(4*rCircumscribe*ca);
  local dy = math.sqrt(math.max(.5*sumD2-.25*goalWidth^2-dx^2, 0));

  -- Predicted pose:
  local x = pos[iMin][1];
  x = x - sign(x) * dx;
  local y = pos[iMin][2];
  y = sign(y) * dy;
  local a = math.atan2(pos[iMin][2] - y, pos[iMin][1] - x) - aPost[iMin];

  pose={};
  pose.x=x;
  pose.y=y;
  pose.a=a;

  aGoal = util.mod_angle((aPost[1]+aPost[2])/2);

  return pose,dGoal,aGoal;
end

function triangulate2(pos,v)

  --New code (for OP)
   local aPost = {};
   local d2Post = {};

   aPost[1] = math.atan2(v[1][2], v[1][1]);
   aPost[2] = math.atan2(v[2][2], v[2][1]);
   d2Post[1] = v[1][1]^2 + v[1][2]^2;
   d2Post[2] = v[2][1]^2 + v[2][2]^2;
   d1 = math.sqrt(d2Post[1]);
   d2 = math.sqrt(d2Post[2]);

   vcm.add_debug_message(string.format(
	"===\n World: triangulation 2\nGoal dist: %.1f / %.1f\nGoal width: %.1f\n",
	d1, d2 ,goalWidth ));


   vcm.add_debug_message(string.format(
	"Measured goal width: %.1f\n",
	 math.sqrt((v[1][1]-v[2][1])^2+(v[1][2]-v[2][2])^2)
	));

--SJ: still testing
   postfix=1;
   postfix=0;

   if postfix>0 then

     if d1>d2 then
       --left post correction based on right post
       -- v1=kcos(a1),ksin(a1)
       -- k^2 - 2k(v[2][1]cos(a1)+v[2][2]sin(a1)) + d2Post[2]-goalWidth^2 = 0
       local ca=math.cos(aPost[1]);
       local sa=math.sin(aPost[1]);
       local b=v[2][1]*ca+ v[2][2]*sa;
       local c=d2Post[2]-goalWidth^2;

       if b*b-c>0 then
         vcm.add_debug_message("Correcting left post\n");
         vcm.add_debug_message(string.format("Left post angle: %d\n",aPost[1]*180/math.pi));

         k1=b-math.sqrt(b*b-c);
         k2=b+math.sqrt(b*b-c);
         vcm.add_debug_message(string.format("d1: %.1f v1: %.1f %.1f\n",
		d1,v[1][1],v[1][2]));
         vcm.add_debug_message(string.format("k1: %.1f v1_1: %.1f %.1f\n",
		k1,k1*ca,k1*sa ));
         vcm.add_debug_message(string.format("k2: %.1f v1_2: %.1f %.1f\n",
		k2,k2*ca,k2*sa ));
         if math.abs(d2-k1)<math.abs(d2-k2) then
	        v[1][1],v[1][2]=k1*ca,k1*sa;
         else
	          v[1][1],v[1][2]=k2*ca,k2*sa;
         end
       end
     else
     --right post correction based on left post
     -- v2=kcos(a2),ksin(a2)
     -- k^2 - 2k(v[1][1]cos(a2)+v[1][2]sin(a2)) + d2Post[1]-goalWidth^2 = 0
     local ca=math.cos(aPost[2]);
     local sa=math.sin(aPost[2]);
     local b=v[1][1]*ca+ v[1][2]*sa;
     local c=d2Post[1]-goalWidth^2;

     if b*b-c>0 then
       k1=b-math.sqrt(b*b-c);
       k2=b+math.sqrt(b*b-c);
       vcm.add_debug_message(string.format("d2: %.1f v2: %.1f %.1f\n",
	d2,v[2][1],v[2][2]));
       vcm.add_debug_message(string.format("k1: %.1f v2_1: %.1f %.1f\n",
	k1,k1*ca,k1*sa ));
       vcm.add_debug_message(string.format("k2: %.1f v2_2: %.1f %.1f\n",
	k2,k2*ca,k2*sa ));
       if math.abs(d2-k1)<math.abs(d2-k2) then
          v[2][1],v[2][2]=k1*ca,k1*sa;
       else
          v[2][1],v[2][2]=k2*ca,k2*sa;
       end
     end
   end

   end

   --Use center of the post to fix angle
   vGoalX=0.5*(v[1][1]+v[2][1]);
   vGoalY=0.5*(v[1][2]+v[2][2]);
   rGoal = math.sqrt(vGoalX^2+vGoalY^2);

   if aPost[1]<aPost[2] then
     aGoal=-math.atan2 ( v[1][1]-v[2][1] , -(v[1][2]-v[2][2]) ) ;
   else
     aGoal=-math.atan2 ( v[2][1]-v[1][1] , -(v[2][2]-v[1][2]) ) ;
   end

   ca=math.cos(aGoal);
   sa=math.sin(aGoal);

   local dx = ca*vGoalX-sa*vGoalY;
   local dy = sa*vGoalX+ca*vGoalY;

   local x0 = 0.5*(pos[1][1]+pos[2][1]);
   local y0 = 0.5*(pos[1][2]+pos[2][2]);

   local x = x0 - sign(x0)*dx;
   local y = -sign(x0)*dy;
   local a=aGoal;
   if x0<0 then a=mod_angle(a+math.pi); end
   local dGoal = rGoal;

   pose={};
   pose.x=x;
   pose.y=y;
   pose.a=a;

 --  aGoal = util.mod_angle((aPost[1]+aPost[2])/2);

   return pose,dGoal,aGoal;
end





function goal_observation(pos, v)
  --Get estimate using triangulation
  if use_new_goalposts==1 then
    pose,dGoal,aGoal=triangulate2(pos,v);
  else
    pose,dGoal,aGoal=triangulate(pos,v);
  end

--  vcm.add_debug_message(string.format("aGoal: %d\n",aGoal*180/math.pi))
--  vcm.add_debug_message(string.format("pos: %.1f %.1f\n",pos[1][1],pos[1][2]))

  local x,y,a=pose.x,pose.y,pose.a;

  local rSigma = .25*dGoal + 0.20;
  local aSigma = 5*math.pi/180;
  local rFilter = rKnownGoalFilter;
  local aFilter = aKnownGoalFilter;

--SJ: testing
triangulation_threshold=4.0;

  if dGoal<triangulation_threshold then


    for ip = 1,n do
      local xErr = x - xp[ip];
      local yErr = y - yp[ip];
      local rErr = math.sqrt(xErr^2 + yErr^2);
      local aErr = mod_angle(a - ap[ip]);
      local err = (rErr/rSigma)^2 + (aErr/aSigma)^2;
      wp[ip] = wp[ip] - err;

      --Filter towards goal:
      xp[ip] = xp[ip] + rFilter*xErr;
      yp[ip] = yp[ip] + rFilter*yErr;
      ap[ip] = ap[ip] + aFilter*aErr;
    end
  else
  --Don't use triangulation for far goals
    goalpos={{(pos[1][1]+pos[2][1])/2, (pos[1][2]+pos[2][2])/2}}
    goalv={(v[1][1]+v[2][1])/2, (v[1][2]+v[2][2])/2}
    landmark_observation(goalpos, goalv , rKnownGoalFilter, aKnownGoalFilter);
  end


end






function goal_observation_unified(pos1,pos2,v)
  vcm.add_debug_message("World: Ambiguous two posts")

  --Get pose estimate from two goalpost locations
  if use_new_goalposts==1 then
    pose1,dGoal1=triangulate2(pos1,v);
    pose2,dGoal2=triangulate2(pos2,v);
  else
    pose1,dGoal1=triangulate(pos1,v);
    pose2,dGoal2=triangulate(pos2,v);
  end

  local x1,y1,a1=pose1.x,pose1.y,pose1.a;
  local x2,y2,a2=pose2.x,pose2.y,pose2.a;

  local rSigma1 = .25*dGoal1 + 0.20;
  local rSigma2 = .25*dGoal2 + 0.20;
  local aSigma = 5*math.pi/180;
  local rFilter = rUnknownGoalFilter;
  local aFilter = aUnknownGoalFilter;

  for ip = 1,n do
    local xErr1 = x1 - xp[ip];
    local yErr1 = y1 - yp[ip];
    local rErr1 = math.sqrt(xErr1^2 + yErr1^2);
    local aErr1 = mod_angle(a1 - ap[ip]);
    local err1 = (rErr1/rSigma1)^2 + (aErr1/aSigma)^2;

    local xErr2 = x2 - xp[ip];
    local yErr2 = y2 - yp[ip];
    local rErr2 = math.sqrt(xErr2^2 + yErr2^2);
    local aErr2 = mod_angle(a2 - ap[ip]);
    local err2 = (rErr2/rSigma2)^2 + (aErr2/aSigma)^2;

    --Filter towards best matching goal:
     if err1>err2 then
      wp[ip] = wp[ip] - err2;
      xp[ip] = xp[ip] + rFilter*xErr2;
      yp[ip] = yp[ip] + rFilter*yErr2;
      ap[ip] = ap[ip] + aFilter*aErr2;
    else
      wp[ip] = wp[ip] - err1;
      xp[ip] = xp[ip] + rFilter*xErr1;
      yp[ip] = yp[ip] + rFilter*yErr1;
      ap[ip] = ap[ip] + aFilter*aErr1;
    end
  end
end



function ball_yellow(v)
  goal_observation(ballYellow, v);
end

function ball_cyan(v)
  goal_observation(ballCyan, v);
end

function goal_yellow(v)
  goal_observation(postYellow, v);
end

function goal_cyan(v)
  goal_observation(postCyan, v);
end

function post_yellow_unknown(v)
  landmark_observation(postYellow, v[1], rKnownPostFilter, aKnownPostFilter);
end

function post_yellow_left(v)
  landmark_observation({postYellow[1]}, v[1], rKnownPostFilter, aKnownPostFilter);
end

function post_yellow_right(v)
  landmark_observation({postYellow[2]}, v[1], rKnownPostFilter, aKnownPostFilter);
end

function post_cyan_unknown(v)
  landmark_observation(postCyan, v[1], rKnownPostFilter, aKnownPostFilter);
end

function post_cyan_left(v)
  landmark_observation({postCyan[1]}, v[1], rKnownPostFilter, aKnownPostFilter);
end

function post_cyan_right(v)
  landmark_observation({postCyan[2]}, v[1], rKnownPostFilter, aKnownPostFilter);
end

function post_unified_unknown(v)
  landmark_observation(postUnified, v[1], rUnknownPostFilter, aUnknownPostFilter);
end

function post_unified_left(v)
  landmark_observation(postLeft, v[1], rUnknownPostFilter, aUnknownPostFilter);
end

function post_unified_right(v)
  landmark_observation(postRight, v[1], rUnknownPostFilter, aUnknownPostFilter);
end

function goal_unified(v)
  goal_observation_unified(postCyan,postYellow, v);
end

function landmark_cyan(v)
  landmark_observation({landmarkCyan}, v, rLandmarkFilter, aLandmarkFilter);
end

function landmark_yellow(v)
  landmark_observation({landmarkYellow}, v, rLandmarkFilter, aLandmarkFilter);
end

function corner(v)	--corner(v,a)
--  print(Lcorner,v,rCornerFilter,aCornerFilter);
--  landmark_observation(Lcorner,v,rCornerFilter,aCornerFilter);
  corner_observation(v,rCornerFilter,aCornerFilter);
--  line(v,a);--Fix heading
end


function line(v, a)
  -- line center
  x = v[1];
  y = v[2];
  r = math.sqrt(x^2 + y^2);

  w0 = .25 / (1 + r/2.0);

  -- TODO: wrap in loop for lua
  for ip = 1,n do
    -- pre-compute sin/cos of orientations
    ca = math.cos(ap[ip]);
    sa = math.sin(ap[ip]);

    -- compute line weight
    local wLine = w0 * (math.cos(4*(ap[ip] + a)) - 1);
    wp[ip] = wp[ip] + wLine;

    local xGlobal = v[1]*ca - v[2]*sa + xp[ip];
    local yGlobal = v[1]*sa + v[2]*ca + yp[ip];

    wBounds = math.max(xGlobal - xLineBoundary, 0) +
              math.max(-xGlobal - xLineBoundary, 0) +
              math.max(yGlobal - yLineBoundary, 0) +
              math.max(-yGlobal - yLineBoundary, 0);
    wp[ip] = wp[ip] - (wBounds/.20);
  end
end

function imuYaw_update(a)
  local aSigma = 15*math.pi/180;
  local aFilter = aImuYawFilter or 0.05;
  for ip = 1,n do
    local da = mod_angle(a - ap[ip]);
    local err = (da/aSigma)^2;
    wp[ip] = wp[ip] - err;

  --Filter toward best matching landmark position:
--print(string.format("%d %.1f %.1f %.1f",ip,xp[ip],yp[ip],ap[ip]));
    ap[ip] = ap[ip] + aFilter * da;
  end
end

function odometry(dx, dy, da)
  for ip = 1,n do
    ca = math.cos(ap[ip]);
    sa = math.sin(ap[ip]);
    xp[ip] = xp[ip] + dx*ca - dy*sa;
    yp[ip] = yp[ip] + dx*sa + dy*ca;
    ap[ip] = ap[ip] + da;
  end
end

function zero_pose()
  xp = vector.zeros(n);
  yp = vector.zeros(n);
  ap = vector.zeros(n);
end

function max(t)
  local imax = 0;
  local tmax = -math.huge;
  for i = 1,#t do
    if (t[i] > tmax) then
      tmax = t[i];
      imax = i;
    end
  end
  return tmax, imax;
end

function min(t)
  local imin = 0;
  local tmin = math.huge;
  for i = 1,#t do
    if (t[i] < tmin) then
      tmin = t[i];
      imin = i;
    end
  end
  return tmin, imin;
end

function sign(x)
  if (x > 0) then
    return 1;
  elseif (x < 0) then
    return -1;
  else
    return 0;
  end
end

function mod_angle(a)
  a = a % (2*math.pi);
  if (a >= math.pi) then
    a = a - 2*math.pi;
  end
  return a;
end

function addNoise()
  add_noise();
end

function add_noise()
  da = 2.0*math.pi/180.0;
  dr = 0.01;
  xp = xp + dr * vector.new(util.randn(n));
  yp = yp + dr * vector.new(util.randn(n));
  ap = ap + da * vector.new(util.randn(n));
end

function resample()
  -- resample particles

  local wLog = {};
  for i = 1,n do
    -- cutoff boundaries
    wBounds = math.max(xp[i]-xMax,0)+math.max(-xp[i]-xMax,0)+
              math.max(yp[i]-yMax,0)+math.max(-yp[i]-yMax,0);
    wLog[i] = wp[i] - wBounds/0.1;
    xp[i] = math.max(math.min(xp[i], xMax), -xMax);
    yp[i] = math.max(math.min(yp[i], yMax), -yMax);
  end

  --Calculate effective number of particles
  wMax, iMax = max(wLog);
  -- total sum
  local wSum = 0;
  -- sum of squares
  local wSum2 = 0;
  local w = {};
  for i = 1,n do
    w[i] = math.exp(wLog[i] - wMax);
    wSum = wSum + w[i];
    wSum2 = wSum2 + w[i]^2;
  end

  local nEffective = (wSum^2) / wSum2;
  if nEffective > .25*n then
    return;
  end

  -- cum sum of weights
  -- wSum[i] = {cumsum(i), index}
  -- used for retrieving the sorted indices
  local wSum = {};
  wSum[1] = {w[1], 1};
  for i = 2,n do
     wSum[i] = {wSum[i-1][1] + w[i], i};
  end

  --normalize
  for i = 1,n do
    wSum[i][1] = wSum[i][1] / wSum[n][1];
  end

  --Add n more particles and resample high n weighted particles
  local rx = util.randu(n);
  local wSum_sz = #wSum;
  for i = 1,n do
    table.insert(wSum, {rx[i], n+i});
  end

  -- sort wSum min->max
  table.sort(wSum, function(a,b) return a[1] < b[1] end);

  -- resample (replace low weighted particles)
  xp2 = vector.zeros(n);
  yp2 = vector.zeros(n);
  ap2 = vector.zeros(n);
  nsampleSum = 1;
  ni = 1;
  for i = 1,2*n do
    oi = wSum[i][2];
    if oi > n then
      xp2[ni] = xp[nsampleSum];
      yp2[ni] = yp[nsampleSum];
      ap2[ni] = ap[nsampleSum];
      ni = ni + 1;
    else
      nsampleSum = nsampleSum + 1;
    end
  end

  --Mirror some particles
--[[
  n_mirror = 10;
  for i=1,n_mirror do
    if i~=iMax then
	xp2[i]=-xp[i];
	yp2[i]=-yp[i];
	ap2[i]=-ap[i];
    end
  end
--]]

  -- always put max particle
  xp2[1] = xp[iMax];
  yp2[1] = yp[iMax];
  ap2[1] = ap[iMax];

  xp = xp2;
  yp = yp2;
  ap = ap2;
  wp = vector.zeros(n);
end
