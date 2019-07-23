local Config = require('Config') -- For Ball and Goal Size
local HeadTransform = require('HeadTransform') -- For Projection
local Body = require('Body')

-- Use center post to determine post type (disabled for OP)
local use_centerpost_ = Config.vision.goal.use_centerpost or 0 -- 0
-- Check the bottom of the post for green
local check_for_ground_ = Config.vision.goal.check_for_ground or 0
-- Min height of goalpost (to reject false positives at the ground)
local goal_height_min_ = Config.vision.goal.height_min or -0.5

local distanceFactor_ = 1.0
if Config.game.playerID > 1 then
  distanceFactor_ = Config.vision.goal.distanceFactor or 1.0 -- 1.5
else
  distanceFactor_ = Config.vision.goal.distanceFactorGoalie or 1 -- 1
end

-- Post dimension
local postDiameter_ = Config.world.postDiameter or 0.10
local postHeight_ = Config.world.goalHeight or 0.80
local goalWidth_ = Config.world.goalWidth or 1.40

local th_goal_separation_ = Config.vision.goal.th_goal_separation -- {0.35, 3.0}

local detect = function(dposts)
  local posts = dposts
  local goal = {}
  goal.detect = 0

  if #posts == 0 then
    return goal
  end

  local tiltAngle = 0
  vcm.set_camera_rollAngle(tiltAngle)

  local headPitch = Body.get_sensor_headpos()[1]

  local function compare_post_score(post1, post2)
    return post1.score > post2.score
  end

  table.sort(posts, compare_post_score)

  local npost = 0
  local ivalidPost = {}
  local postA = {} -- valided posts

  for i = 1, #posts do
    posts[i].centroid = {
      posts[i].x + posts[i].w / 2., posts[i].y + posts[i].h / 2.,
    }
    local valid = true
    if valid then
      -- Height Check
      local scale = math.sqrt((posts[i].w * posts[i].h) /
                                  (postDiameter_ * postHeight_))
      local v = HeadTransform.coordinatesA(posts[i].centroid, scale)
      if v[3] < goal_height_min_ then
        --      vcm.add_debug_message(string.format("Height check fail:%.2f\n",v[3]));
        print("a, " .. i .. "th post unvalid: " .. v[3])
        valid = false
      end
    end

    if (valid and npost == 1) then
      -- dGoal, x pixels between two posts, postA means last post
      local dGoal = math.abs(posts[i].centroid[1] - postA[1].centroid[1])
      local dPost = math.max(postA[1].w, posts[i].w)
      local separation = dGoal / dPost
      -- distances between posts judge
      if (separation < th_goal_separation_[1]) then
        print("b, " .. i .. "th post unvalid: " .. separation)
        valid = false
      end
    end

    if (valid) then
      ivalidPost[#ivalidPost + 1] = i
      npost = npost + 1
      postA[npost] = posts[i]
    end
    if (npost == 2) then
      break
    end
  end -- End for #posts

  if (npost < 1) then
    return goal
  end

  goal.v = {}

  for i = 1, (math.min(npost, 2)) do
    local scale1 = postA[i].w / postDiameter_
    local scale2 = postA[i].h / postHeight_
    local scale3 = math.sqrt((postA[i].w * postA[i].h) /
                                 (postDiameter_ * postHeight_))

    -- TODO(b51): should we use the max scale?
    local scale = math.max(scale1, scale2, scale3)

    goal.v[i] = HeadTransform.coordinatesA(postA[i].centroid, scale)

    goal.v[i][1] = goal.v[i][1] * distanceFactor_
    goal.v[i][2] = goal.v[i][2] * distanceFactor_
  end

  if (npost == 2) then
    goal.type = 3 -- Two posts
  else
    goal.v[2] = vector.new({0, 0, 0, 0})

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
    -- TODO(b51): treat all single post as unkown post for temp,
    --            in the future may add left/right post data to training
    local dxCrossbar = 0 -- Should be unknown post
    if (math.abs(dxCrossbar) > 0.6 * posts[1].w) then
      if (dxCrossbar > 0) then
        if use_centerpost_ > 0 then
          goal.type = 1 -- left post
        else
          goal.type = 0 -- unknown post
        end
      else
        if use_centerpost_ > 0 then
          goal.type = 2 -- right post
        else
          goal.type = 0 -- unknown post
        end
      end
    else
      -- unknown post
      goal.type = 0
    end
  end

  -- added for test_vision.m
  if Config.vision.copy_image_to_shm then
    vcm.set_goal_postBoundingBox1({
      postA[1].x, postA[1].y, postA[1].w, postA[1].h,
    })
    vcm.set_goal_postCentroid1({postA[1].centroid[1], postA[1].centroid[2]})
    vcm.set_goal_postAxis1({postA[1].w, postA[1].h})
    if npost == 2 then
      vcm.set_goal_postBoundingBox2({
        postA[2].x, postA[2].y, postA[2].w, postA[2].h,
      })
      vcm.set_goal_postCentroid2({postA[2].centroid[1], postA[2].centroid[2]})
      vcm.set_goal_postAxis2({postA[2].w, postA[2].h})
    else
      vcm.set_goal_postBoundingBox2({0, 0, 0, 0})
    end
  end

  goal.detect = 1
  return goal
end

return {detect = detect}

