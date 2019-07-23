local Config = require('Config')
local PoseFilter = require('PoseFilter')
local Filter2D = require('Filter2D')
local Body = require('Body')
local vector = require('vector')
local util = require('util')
local wcm = require('wcm')
local vcm = require('vcm')
local gcm = require('gcm')
local mcm = require('mcm')
local Velocity = require('Velocity')

-- SJ: Velocity filter is always on
-- We can toggle whether to use velocity to update ball position estimate
-- In Filter2D.lua

local mod_angle = util.mod_angle

-- Are we using same colored goals?
local use_same_colored_goal_ = Config.world.use_same_colored_goal or 0

-- Use team vision information when we cannot find the ball ourselves
local tVisionBall_ = 0
local use_team_ball_ = Config.team.use_team_ball or 0
local team_ball_timeout_ = Config.team.team_ball_timeout or 0
local team_ball_threshold_ = Config.team.team_ball_threshold or 0
local imuYaw_of_fieldXp_ = Config.world.imuYaw_of_fieldXp or 0
local imuYaw_of_fieldXm_ = Config.world.imuYaw_of_fieldXm or 0
local imuYaw_of_fieldYp_ = Config.world.imuYaw_of_fieldYp or 0
local imuYaw_of_fieldYm_ = Config.world.imuYaw_of_fieldYm or 0

-- TODO(b51): indicator is LED signal, need delete

local ballFilter = Filter2D.new()
local ball_ = {}
ball_.t = 0 -- Detection time
ball_.x = 1.0
ball_.y = 0
ball_.vx = 0
ball_.vy = 0
ball_.p = 0

local pose_ = {}
pose_.x = 0
pose_.y = 0
pose_.a = 0
pose_.tGoal = 0 -- Goal detection time

local count_ = 0
local imuYaw_count_ = 0
local cResample_ = Config.world.cResample
local cimuYaw_count_ = Config.world.cimuYaw_count

local odomScale_ = Config.walk.odomScale or Config.world.odomScale
local imuYaw_update_ = Config.world.imuYaw_update or 1
wcm.set_robot_odomScale(odomScale_)

-- SJ: they are for IMU based navigation
local imuYaw_ = Config.world.imuYaw or 0
local yaw0_ = 0

-- Track gcm state
local gameState_ = 0

local get_ball = function()
  return ball_
end

local get_pose = function()
  return pose_
end

local zero_pose = function()
  PoseFilter.zero_pose()
end

-- Get attack bearing from pose0
local get_attack_bearing_pose = function(pose0)
  local postAttack
  if gcm.get_team_color() == 1 then
    -- red attacks cyan goal
    postAttack = PoseFilter.postCyan()
  else
    -- blue attack yellow goal
    postAttack = PoseFilter.postYellow()
  end

  -- make sure not to shoot back towards defensive goal:
  local xPose = math.min(math.max(pose0.x, -0.99 * PoseFilter.xLineBoundary),
                         0.99 * PoseFilter.xLineBoundary)
  local yPose = pose0.y
  local aPost = {}
  aPost[1] = math.atan2(postAttack[1][2] - yPose, postAttack[1][1] - xPose)
  aPost[2] = math.atan2(postAttack[2][2] - yPose, postAttack[2][1] - xPose)
  local daPost = math.abs(PoseFilter.mod_angle(aPost[1] - aPost[2]))
  local attackHeading = aPost[2] + .5 * daPost
  local attackBearing = PoseFilter.mod_angle(attackHeading - pose0.a)

  return attackBearing, daPost
end

local get_attack_bearing = function()
  return get_attack_bearing_pose(pose_)
end

local get_attack_posts = function()
  if gcm.get_team_color() == 1 then
    return Config.world.postCyan
  else
    return Config.world.postYellow
  end
end

local get_attack_angle = function()
  local goalAttack = get_goal_attack()
  local dx = goalAttack[1] - pose_.x
  local dy = goalAttack[2] - pose_.y
  return mod_angle(math.atan2(dy, dx) - pose_.a)
end

local get_goal_attack = function()
  if gcm.get_team_color() == 1 then
    -- red attacks cyan goal
    return {PoseFilter.postCyan()[1][1], 0, 0}
  else
    -- blue attack yellow goal
    return {PoseFilter.postYellow()[1][1], 0, 0}
  end
end

local get_defend_angle = function()
  local goalDefend = get_goal_defend()
  local dx = goalDefend[1] - pose_.x
  local dy = goalDefend[2] - pose_.y
  return mod_angle(math.atan2(dy, dx) - pose_.a)
end

local get_goal_defend = function()
  if gcm.get_team_color() == 1 then
    -- red defends yellow goal
    return {PoseFilter.postYellow()[1][1], 0, 0}
  else
    -- blue defends cyan goal
    return {PoseFilter.postCyan()[1][1], 0, 0}
  end
end

local get_team_color = function()
  return gcm.get_team_color()
end

local pose_global = function(pRelative, pose)
  local ca = math.cos(pose[3])
  local sa = math.sin(pose[3])
  return vector.new{
    pose[1] + ca * pRelative[1] - sa * pRelative[2],
    pose[2] + sa * pRelative[1] + ca * pRelative[2], pose[3] + pRelative[3],
  }
end

local pose_relative = function(pGlobal, pose)
  local ca = math.cos(pose[3])
  local sa = math.sin(pose[3])
  local px = pGlobal[1] - pose[1]
  local py = pGlobal[2] - pose[2]
  local pa = pGlobal[3] - pose[3]
  return vector.new{ca * px + sa * py, -sa * px + ca * py, mod_angle(pa)}
end

local get_imuYaw = function()
  local a = Body.get_sensor_imuAngle(3)
  a = mod_angle(a - imuYaw_of_fieldXp_)
  return a
end

local init_particles = function()
  if use_same_colored_goal_ > 0 then
    local goalDefend = get_goal_defend()
    PoseFilter.initialize_unified(vector.new(
                                      {goalDefend[1] / 2, -3, math.pi / 2}), -- 暂不清楚goalDefend得到的是什么，-3是由之前的-2改过来的 还需研究
                                  vector.new(
                                      {goalDefend[1] / 2, 3, -math.pi / 2}))
  else
    PoseFilter.initialize(nil, nil)
  end
end

local init_particles_manual_placement = function()
  if gcm.get_team_role() == 0 then
    -- goalie initialized to different place
    local goalDefend = get_goal_defend()
    util.ptable(goalDefend)
    local dp = vector.new({0.04, 0.04, math.pi / 8})
    if goalDefend[1] > 0 then
      PoseFilter.initialize(vector.new({goalDefend[1], 0, math.pi}), dp)
    else
      PoseFilter.initialize(vector.new({goalDefend[1], 0, 0}), dp)
    end
  else
    PoseFilter.initialize_manual_placement()
  end
end

local allLessThanTenth = function(table)
  for k, v in pairs(table) do
    if v >= .1 then
      return false
    end
  end
  return true
end

local allZeros = function(table)
  for k, v in pairs(table) do
    if v ~= 0 then
      return false
    end
  end
  return true
end

local update_shm = function()
  -- update shm values
  wcm.set_robot_pose({pose_.x, pose_.y, pose_.a})
  wcm.set_robot_time(Body.get_time())

  wcm.set_ball_x(ball_.x)
  wcm.set_ball_y(ball_.y)
  wcm.set_ball_t(ball_.t)
  wcm.set_ball_velx(ball_.vx)
  wcm.set_ball_vely(ball_.vy)
  wcm.set_ball_p(ball_.p)

  wcm.set_goal_t(pose_.tGoal)
  wcm.set_goal_attack(get_goal_attack())
  wcm.set_goal_defend(get_goal_defend())
  wcm.set_goal_attack_bearing(get_attack_bearing())
  wcm.set_goal_attack_angle(get_attack_angle())
  wcm.set_goal_defend_angle(get_defend_angle())

  wcm.set_goal_attack_post1(get_attack_posts()[1])
  wcm.set_goal_attack_post2(get_attack_posts()[2])

  wcm.set_robot_is_fall_down(mcm.get_walk_isFallDown())
  -- Particle information
  wcm.set_particle_x(PoseFilter.xp())
  wcm.set_particle_y(PoseFilter.yp())
  wcm.set_particle_a(PoseFilter.ap())
  wcm.set_particle_w(PoseFilter.wp())
end

local update_odometry = function()
  odomScale_ = wcm.get_robot_odomScale()
  count_ = count_ + 1
  local uOdometry, uOdometry0 = mcm.get_odometry(uOdometry0)

  uOdometry[1] = odomScale_[1] * uOdometry[1]
  uOdometry[2] = odomScale_[2] * uOdometry[2]
  uOdometry[3] = odomScale_[3] * uOdometry[3]
  -- Gyro integration based IMU
  if imuYaw_ == 1 then
    local yaw = Body.get_sensor_imuAngle()[3]
    print("yaw :", yaw * 180 / math.pi)
    uOdometry[3] = yaw - yaw0_
    yaw0_ = yaw
  end
  ballFilter:odometry(uOdometry[1], uOdometry[2], uOdometry[3])
  PoseFilter.odometry(uOdometry[1], uOdometry[2], uOdometry[3])
end

local update_pos = function()
  -- update localization without vision (for odometry testing)
  if count_ % cResample_ == 0 then
    PoseFilter.resample()
  end
  pose_.x, pose_.y, pose_.a = PoseFilter.get_pose()
  update_shm()
end

local update_vision = function()
  local imuangle = Body.get_sensor_imuAngle()

  -- update ground truth
  wcm.set_robot_gpspose({pose_.x, pose_.y, pose_.a})
  wcm.set_robot_gps_attackbearing(get_attack_bearing())

  -- resample?
  if count_ % cResample_ == 0 then
    PoseFilter.resample()
    PoseFilter.add_noise()
  end

  -- Reset heading if robot is down
  if (mcm.get_walk_isFallDown() == 1) then
    PoseFilter.reset_heading()
  end

  gameState_ = gcm.get_game_state()
  if (gameState_ == 0) then
    init_particles()
  end

  -- If robot was in penalty and game switches to set, initialize particles
  -- for manual placement
  if wcm.get_robot_penalty() == 1 and gcm.get_game_state() == 2 then
    init_particles_manual_placement()
  elseif gcm.in_penalty() then
    init_particles()
  end

  -- Penalized?
  if gcm.in_penalty() then
    wcm.set_robot_penalty(1)
  else
    wcm.set_robot_penalty(0)
  end

  local fsrRight = Body.get_sensor_fsrRight()
  local fsrLeft = Body.get_sensor_fsrLeft()

  -- reset particle to face opposite goal when getting manual placement on set
  if gcm.get_game_state() == 2 then
    if (not allZeros(fsrRight)) and (not allZeros(fsrLeft)) then -- Do not do this if sensor is broken
      if allLessThanTenth(fsrRight) and allLessThanTenth(fsrLeft) then
        init_particles_manual_placement()
      end
    end
  end

  -- ball
  local ball_gamma = 0.3
  if (vcm.get_ball_detect() == 1) then
    tVisionBall_ = Body.get_time()
    ball_.t = Body.get_time()
    ball_.p = (1 - ball_gamma) * ball_.p + ball_gamma
    local v = vcm.get_ball_v()
    local dr = vcm.get_ball_dr()
    local da = vcm.get_ball_da()
    ballFilter:observation_xy(v[1], v[2], dr, da)

    -- Update the velocity
    -- Velocity.update(v[1],v[2]);
    -- use centroid info only
    ball_v_inf = wcm.get_ball_v_inf()
    Velocity.update(ball_v_inf[1], ball_v_inf[2])

    ball_.vx, ball_.vy, dodge = Velocity.getVelocity()
  else
    ball_.p = (1 - ball_gamma) * ball_.p
    Velocity.update_noball() -- notify that ball is missing
  end
  -- TODO: handle goal detections more generically

  if vcm.get_goal_detect() == 1 then
    pose_.tGoal = Body.get_time()
    local color = vcm.get_goal_color()
    local goalType = vcm.get_goal_type()
    local v1 = vcm.get_goal_v1()
    local v2 = vcm.get_goal_v2()
    local v = {v1, v2}

    if (use_same_colored_goal_ > 0) then
      -- resolve attacking/defending goal using imu
      --  0 - unknown
      -- -1 - yellow    defending
      -- +1 - cyan      attacking
      local yellowOrCyan = 0
      local a = get_imuYaw()
      yellowOrCyan = PoseFilter.imuGoal(goalType, v, a)
      if (yellowOrCyan == -1) then
        -- yellow goal
        if (goalType == 0) then
          PoseFilter.post_yellow_unknown(v)
        elseif (goalType == 1) then
          PoseFilter.post_yellow_left(v)
        elseif (goalType == 2) then
          PoseFilter.post_yellow_right(v)
        elseif (goalType == 3) then
          PoseFilter.goal_yellow(v)
        end
      elseif (yellowOrCyan == 1) then
        -- cyan goal
        if (goalType == 0) then
          PoseFilter.post_cyan_unknown(v)
        elseif (goalType == 1) then
          PoseFilter.post_cyan_left(v)
        elseif (goalType == 2) then
          PoseFilter.post_cyan_right(v)
        elseif (goalType == 3) then
          PoseFilter.goal_cyan(v)
        end
      else
        -- we dont know which goal it is
        if (goalType == 0) then
          PoseFilter.post_unified_unknown(v)
        elseif (goalType == 1) then
          PoseFilter.post_unified_left(v)
        elseif (goalType == 2) then
          PoseFilter.post_unified_right(v)
        elseif (goalType == 3) then
          PoseFilter.goal_unified(v)
        end
      end
      --[[
      if (attackingOrDefending == 1) then
        -- attacking goal
        if (gcm.get_team_color() == 1) then
          -- we are the red team, shooting on cyan goal
          if (goalType == 0) then
            PoseFilter.post_cyan_unknown(v);
          elseif(goalType == 1) then
            PoseFilter.post_cyan_left(v);
          elseif(goalType == 2) then
            PoseFilter.post_cyan_right(v);
          elseif(goalType == 3) then
            PoseFilter.goal_cyan(v);
          end
          -- indicator
          Body.set_indicator_goal({0,0,1});
        else
          -- we are the blue team, shooting on yellow goal
          if (goalType == 0) then
            PoseFilter.post_yellow_unknown(v);
          elseif(goalType == 1) then
            PoseFilter.post_yellow_left(v);
          elseif(goalType == 2) then
            PoseFilter.post_yellow_right(v);
          elseif(goalType == 3) then
            PoseFilter.goal_yellow(v);
          end
          -- indicator
          Body.set_indicator_goal({1,1,0});
        end

      elseif (attackingOrDefending == -1) then
        -- defending goal
        if (gcm.get_team_color() == 1) then
          -- we are the red team, defending the yellow goal
          if (goalType == 0) then
            PoseFilter.post_yellow_unknown(v);
          elseif(goalType == 1) then
            PoseFilter.post_yellow_left(v);
          elseif(goalType == 2) then
            PoseFilter.post_yellow_right(v);
          elseif(goalType == 3) then
            PoseFilter.goal_yellow(v);
          end
          -- indicator
          Body.set_indicator_goal({1,1,0});
        else
          if (goalType == 0) then
            PoseFilter.post_cyan_unknown(v);
          elseif(goalType == 1) then
            PoseFilter.post_cyan_left(v);
          elseif(goalType == 2) then
            PoseFilter.post_cyan_right(v);
          elseif(goalType == 3) then
            PoseFilter.goal_cyan(v);
          end
          -- indicator
          Body.set_indicator_goal({0,0,1});
        end

      else
        -- we dont know which goal it is
        if (goalType == 0) then
          PoseFilter.post_unified_unknown(v);
          Body.set_indicator_goal({1,1,0});
        elseif(goalType == 1) then
          PoseFilter.post_unified_left(v);
          Body.set_indicator_goal({1,1,0});
        elseif(goalType == 2) then
          PoseFilter.post_unified_right(v);
          Body.set_indicator_goal({1,1,0});
        elseif(goalType == 3) then
          PoseFilter.goal_unified(v);
          Body.set_indicator_goal({0,0,1});
        end
      end
--]]

    else
      -- Goal observation with colors
      if color == Config.color.yellow then
        if (goalType == 0) then
          PoseFilter.post_yellow_unknown(v)
        elseif (goalType == 1) then
          PoseFilter.post_yellow_left(v)
        elseif (goalType == 2) then
          PoseFilter.post_yellow_right(v)
        elseif (goalType == 3) then
          PoseFilter.goal_yellow(v)
        end
      elseif color == Config.color.cyan then
        if (goalType == 0) then
          PoseFilter.post_cyan_unknown(v)
        elseif (goalType == 1) then
          PoseFilter.post_cyan_left(v)
        elseif (goalType == 2) then
          PoseFilter.post_cyan_right(v)
        elseif (goalType == 3) then
          PoseFilter.goal_cyan(v)
        end
      end
    end
  end

  -- line update
  if vcm.get_line_detect() == 1 then
    local v = vcm.get_line_v()
    local a = vcm.get_line_angle()
    PoseFilter.line(v, a) -- use longest line in the view
  end

  if vcm.get_corner_detect() == 1 then
    local v = vcm.get_corner_v()
    PoseFilter.corner(v)
  end

  if vcm.get_landmark_detect() == 1 then
    local color = vcm.get_landmark_color()
    local v = vcm.get_landmark_v()
    if color == Config.color.yellow then
      PoseFilter.landmark_yellow(v)
    else
      PoseFilter.landmark_cyan(v)
    end
  end

  -- imuYaw update
  if imuYaw_update_ == 1 then
    imuYaw_count_ = imuYaw_count_ + 1
    if imuYaw_count_ == cimuYaw_count_ then
      local a = get_imuYaw()
      -- print(a*180/math.pi);
      PoseFilter.imuYaw_update(a)
      imuYaw_count_ = 0
    end
  end

  ball_.x, ball_.y = ballFilter:get_xy()
  pose_.x, pose_.y, pose_.a = PoseFilter.get_pose()

  -- print(string.format("\t%.2f,\t%.2f,\t%.2f,\t%.2f",pose.x*100,pose.y*100,pose.a*180/math.pi,imua*180/math.pi));
  -- Use team vision information when we cannot find the ball ourselves

  local team_ball = wcm.get_robot_team_ball()
  local team_ball_score = wcm.get_robot_team_ball_score()

  local t = Body.get_time()
  if use_team_ball_ > 0 and (t - tVisionBall_) > team_ball_timeout_ and
      team_ball_score > team_ball_threshold_ then
    ballLocal = util.pose_relative({team_ball[1], team_ball[2], 0},
                                   {pose_.x, pose_.y, pose_.a})
    ball_.x = ballLocal[1]
    ball_.y = ballLocal[2]
    ball_.t = t
  end
  update_shm()
end

local entry = function()
  count_ = 0
  init_particles()
  Velocity.entry()
  PoseFilter.corner_init()
end

local exit = function()
end

return {
  entry = entry,
  update_shm = update_shm,
  update_odometry = update_odometry,
  update_pos = update_pos,
  update_vision = update_vision,
  exit = exit,
  get_ball = get_ball,
  get_pose = get_pose,
  zero_pose = zero_pose,
  get_attack_bearing_pose = get_attack_bearing_pose,
  get_attack_bearing = get_attack_bearing,
  get_attack_angle = get_attack_angle,
  get_attack_posts = get_attack_posts,
  get_goal_attack = get_goal_attack,
  get_defend_angle = get_defend_angle,
  get_goal_defend = get_goal_defend,
  get_team_color = get_team_color,
  pose_global = pose_global,
  pose_relative = pose_relative,
  get_imuYaw = get_imuYaw,
  init_particles = init_particles,
  init_particles_manual_placement = init_particles_manual_placement,
  allLessThanTenth = allLessThanTenth,
  allZeros = allZeros,
}

