module(..., package.seeall);

require('Config');	-- For Ball and Goal Size
require('HeadTransform');	-- For Projection
require('Body')

-- Dependency
require('Detection');

--this threshold makes sure that the posts don't have more than a certain ratio of their length under the horizon
goalHorizonCheck = 1.0;

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

th_goal_separation = Config.vision.goal.th_goal_separation; --{0.35, 3.0}

function detect(dposts)
  local posts = dposts;
  local goal = {};
  goal.detect = 0;

  if #posts == 0 then
    return goal
  end

  local tiltAngle=0;
  vcm.set_camera_rollAngle(tiltAngle);

  headPitch = Body.get_sensor_headpos()[1];

  local function compare_post_score(post1, post2)
    return post1.score > post2.score
  end

  table.sort(posts, compare_post_score)

  local npost = 0;
  local ivalidPost = {};
  local postA = {}; -- valided posts

  lower_factor = 0.3;

  for i = 1, #posts do
		posts[i].centroid = {posts[i].x + posts[i].w / 2.,
                         posts[i].y + posts[i].h / 2.};

    local valid = true;

    if valid then
    --Height Check
      scale = math.sqrt((posts[i].w*posts[i].h) / (postDiameter*postHeight));
      v = HeadTransform.coordinatesA(posts[i].centroid, scale);
      if v[3] < goal_height_min then
--      vcm.add_debug_message(string.format("Height check fail:%.2f\n",v[3]));
        print("a, "..i.."th post unvalid: "..v[3]);
        valid = false;
      end
    end

    if (valid and npost==1) then
      -- dGoal, x pixels between two posts, postA means last post
      local dGoal = math.abs(posts[i].centroid[1]-postA[1].centroid[1]);
      local dPost = math.max(postA[1].w, posts[i].w);
      local separation=dGoal/dPost;
      -- distances between posts judge
      if (separation < th_goal_separation[1]) then
        print("b, "..i.."th post unvalid: "..separation);
        valid = false;
      end
    end

    if (valid) then
      ivalidPost[#ivalidPost + 1] = i;
      npost = npost + 1;
      postA[npost] = posts[i];
    end
    if (npost==2)then
      break
    end
  end -- End for #posts

  if (npost < 1) then
    return goal;
  end

  goal.v = {};

  for i = 1,(math.min(npost, 2)) do
    scale1 = postA[i].w / postDiameter;
    scale2 = postA[i].h / postHeight;
    scale3 = math.sqrt((postA[i].w * postA[i].h) / (postDiameter*postHeight) );

    --TODO(b51): should we use the max scale?
    scale = math.max(scale1,scale2,scale3);

    goal.v[i] = HeadTransform.coordinatesA(postA[i].centroid, scale);

    goal.v[i][1]=goal.v[i][1]*distanceFactor;
    goal.v[i][2]=goal.v[i][2]*distanceFactor;
  end

  if (npost == 2) then
    goal.type = 3; --Two posts
  else
    goal.v[2] = vector.new({0,0,0,0});

    -- look for crossbar:
    --[[
    local postWidth = postA[1].w;
    local leftX = postA[1].x - 5*postWidth;
    local rightX = postA[1].x + postA[1].w + 5*postWidth;
    local topY = postA[1].y-5*postWidth;
    local bottomY = postA[1].y + postA[1].h + 5*postWidth;
    local bboxA = {leftX, rightX, topY, bottomY};

    local crossbarStats = ImageProc.color_stats(Vision.labelA.data, Vision.labelA.m, Vision.labelA.n, color, bboxA,tiltAngle);
    local dxCrossbar = crossbarStats.centroid[1] - postA[1].centroid[1];
    local crossbar_ratio = dxCrossbar/postWidth;

    --If the post touches the top, it should be a unknown post
    if goal.propsB[1].boundingBox[3]<3 then --touching the top
      dxCrossbar = 0; --Should be unknown post
    end
    --]]
    -- TODO(b51): treate all single post as unkown post for temp
    --            will add left/right post data to training
    dxCrossbar = 0; --Should be unknown post
    if (math.abs(dxCrossbar) > 0.6*posts[1].w) then
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
    end
  end

-- added for test_vision.m
  if Config.vision.copy_image_to_shm then
      vcm.set_goal_postBoundingBox1({postA[1].x, postA[1].y, postA[1].w, postA[1].h});
      vcm.set_goal_postCentroid1({postA[1].centroid[1], postA[1].centroid[2]});
      vcm.set_goal_postAxis1({postA[1].w, postA[1].h});
      if npost == 2 then
        vcm.set_goal_postBoundingBox2({postA[2].x, postA[2].y, postA[2].w, postA[2].h});
        vcm.set_goal_postCentroid2({postA[2].centroid[1],postA[2].centroid[2]});
        vcm.set_goal_postAxis2({postA[2].w,postA[2].h});
      else
        vcm.set_goal_postBoundingBox2({0,0,0,0});
      end
  end

  goal.detect = 1;
  return goal;
end
