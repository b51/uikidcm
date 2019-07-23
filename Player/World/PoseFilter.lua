local Config = require('Config')
local vector = require('vector')
local vcm = require('vcm')
local util = require('util')

local n_ = Config.world.n
local xLineBoundary_ = Config.world.xLineBoundary
local yLineBoundary_ = Config.world.yLineBoundary
local xMax_ = Config.world.xMax
local yMax_ = Config.world.yMax

local goalWidth_ = Config.world.goalWidth
-- TODO(b51): postYellow, postCyan, landmarkYellow, landmarkCyan, ballYellow, ballCyan useless
--            need remove
local postYellow_ = Config.world.postYellow
local postCyan_ = Config.world.postCyan
local landmarkYellow_ = Config.world.landmarkYellow
local landmarkCyan_ = Config.world.landmarkCyan
local spot_ = Config.world.spot
local ballYellow_ = Config.world.ballYellow
local ballCyan_ = Config.world.ballCyan
local Lcorner_ = Config.world.Lcorner

-- Are we using same colored goals?
local use_same_colored_goal = Config.world.use_same_colored_goal or 0

-- Triangulation method selection
local use_new_goalposts_ = Config.world.use_new_goalposts or 0

-- For single-colored goalposts
local postUnified_ = {
  postYellow_[1], postYellow_[2], postCyan_[1], postCyan_[2],
}
local postLeft_ = {postYellow_[1], postCyan_[1]}
local postRight_ = {postYellow_[2], postCyan_[2]}

local rGoalFilter_ = Config.world.rGoalFilter
local aGoalFilter_ = Config.world.aGoalFilter
local rPostFilter_ = Config.world.rPostFilter
local aPostFilter_ = Config.world.aPostFilter
local rKnownGoalFilter_ = Config.world.rKnownGoalFilter or
                              Config.world.rGoalFilter
local aKnownGoalFilter_ = Config.world.aKnownGoalFilter or
                              Config.world.aGoalFilter
local rKnownPostFilter_ = Config.world.rKnownPostFilter or
                              Config.world.rPostFilter
local aKnownPostFilter_ = Config.world.aKnownPostFilter or
                              Config.world.aPostFilter
local rUnknownGoalFilter_ = Config.world.rUnknownGoalFilter or
                                Config.world.rGoalFilter
local aUnknownGoalFilter_ = Config.world.aUnknownGoalFilter or
                                Config.world.aGoalFilter
local rUnknownPostFilter_ = Config.world.rUnknownPostFilter or
                                Config.world.rPostFilter
local aUnknownPostFilter_ = Config.world.aUnknownPostFilter or
                                Config.world.aPostFilter

local rLandmarkFilter_ = Config.world.rLandmarkFilter
local aLandmarkFilter_ = Config.world.aLandmarkFilter

local rCornerFilter_ = Config.world.rCornerFilter
local aCornerFilter_ = Config.world.aCornerFilter

local aImuYawFilter_ = Config.world.aImuYawFilter

local xp_ = .5 * xMax_ * vector.new(util.randn(n_))
local yp_ = .5 * yMax_ * vector.new(util.randn(n_))
local ap_ = 2 * math.pi * vector.new(util.randu(n_))
local wp_ = vector.zeros(n_)

local corner_lut_a_ = {}
local corner_lut_r_ = {}
local goalAngleThres_ = Config.world.imuGoal_angleThres or 30 * math.pi / 180

local xp = function()
  return xp_
end

local yp = function()
  return yp_
end

local ap = function()
  return ap_
end

local wp = function()
  return wp_
end

local max = function(t)
  local imax = 0
  local tmax = -math.huge
  for i = 1, #t do
    if (t[i] > tmax) then
      tmax = t[i]
      imax = i
    end
  end
  return tmax, imax
end

local min = function(t)
  local imin = 0
  local tmin = math.huge
  for i = 1, #t do
    if (t[i] < tmin) then
      tmin = t[i]
      imin = i
    end
  end
  return tmin, imin
end

local sign = function(x)
  if (x > 0) then
    return 1
  elseif (x < 0) then
    return -1
  else
    return 0
  end
end

local mod_angle = function(a)
  a = a % (2 * math.pi)
  if (a >= math.pi) then
    a = a - 2 * math.pi
  end
  return a
end

local postCyan = function()
  return postCyan_
end

local postYellow = function()
  return postYellow_
end

-- TODO(b51): make noise as a Config parameter
local add_noise = function()
  local da = 2.0 * math.pi / 180.0
  local dr = 0.01
  xp_ = xp_ + dr * vector.new(util.randn(n_))
  yp_ = yp_ + dr * vector.new(util.randn(n_))
  ap_ = ap_ + da * vector.new(util.randn(n_))
end

local resample = function()
  -- resample particles

  local wLog = {}
  for i = 1, n_ do
    -- cutoff boundaries
    local wBounds = math.max(xp_[i] - xMax_, 0) + math.max(-xp_[i] - xMax_, 0) +
                        math.max(yp_[i] - yMax_, 0) +
                        math.max(-yp_[i] - yMax_, 0)
    wLog[i] = wp_[i] - wBounds / 0.1
    xp_[i] = math.max(math.min(xp_[i], xMax_), -xMax_)
    yp_[i] = math.max(math.min(yp_[i], yMax_), -yMax_)
  end

  -- Calculate effective number of particles
  local wMax, iMax = max(wLog)
  -- total sum
  local wSum = 0
  -- sum of squares
  local wSum2 = 0
  local w = {}
  for i = 1, n_ do
    w[i] = math.exp(wLog[i] - wMax)
    wSum = wSum + w[i]
    wSum2 = wSum2 + w[i] ^ 2
  end

  local nEffective = (wSum ^ 2) / wSum2
  if nEffective > .25 * n_ then
    return
  end

  -- cum sum of weights
  -- wSum[i] = {cumsum(i), index}
  -- used for retrieving the sorted indices
  local wSum = {}
  wSum[1] = {w[1], 1}
  for i = 2, n_ do
    wSum[i] = {wSum[i - 1][1] + w[i], i}
  end

  -- normalize
  for i = 1, n_ do
    wSum[i][1] = wSum[i][1] / wSum[n_][1]
  end

  -- Add n more particles and resample high n weighted particles
  local rx = util.randu(n_)
  local wSum_sz = #wSum
  for i = 1, n_ do
    table.insert(wSum, {rx[i], n_ + i})
  end

  -- sort wSum min->max
  table.sort(wSum, function(a, b)
    return a[1] < b[1]
  end)

  -- resample (replace low weighted particles)
  local xp2 = vector.zeros(n_)
  local yp2 = vector.zeros(n_)
  local ap2 = vector.zeros(n_)
  local nsampleSum = 1
  local ni = 1
  for i = 1, 2 * n_ do
    local oi = wSum[i][2]
    if oi > n_ then
      xp2[ni] = xp_[nsampleSum]
      yp2[ni] = yp_[nsampleSum]
      ap2[ni] = ap_[nsampleSum]
      ni = ni + 1
    else
      nsampleSum = nsampleSum + 1
    end
  end

  -- Mirror some particles
  --[[
  n_mirror = 10;
  for i=1,n_mirror do
    if i~=iMax then
	xp2[i]=-xp_[i];
	yp2[i]=-yp_[i];
	ap2[i]=-ap_[i];
    end
  end
--]]

  -- always put max particle
  xp2[1] = xp_[iMax]
  yp2[1] = yp_[iMax]
  ap2[1] = ap_[iMax]

  xp_ = xp2
  yp_ = yp2
  ap_ = ap2
  wp_ = vector.zeros(n_)
end

local corner_init = function()
  local x0 = -3.05
  local y0 = -2.05

  for ix = 1, 60 do
    local x = x0 + ix * .1
    corner_lut_a_[ix] = {}
    corner_lut_r_[ix] = {}
    for iy = 1, 40 do
      local y = y0 + iy * .1
      corner_lut_a_[ix][iy] = vector.zeros(#Lcorner_)
      corner_lut_r_[ix][iy] = vector.zeros(#Lcorner_)
      for ipos = 1, #Lcorner_ do
        local dx = Lcorner_[ipos][1] - x
        local dy = Lcorner_[ipos][2] - y
        corner_lut_r_[ix][iy][ipos] = math.sqrt(dx ^ 2 + dy ^ 2)
        corner_lut_a_[ix][iy][ipos] = math.atan2(dy, dx)
      end
    end
  end
end

local imuGoal = function(gtype, vgoal, imuYaw)
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
  local post1 = vgoal[1]
  local post2 = vgoal[2]
  local agoal = math.atan2(post1[2], post1[1])
  if (gtype == 3) then
    -- if both posts were detected then use the angle between the two
    agoal = util.mod_angle(post1[3] + 0.5 *
                               util.mod_angle(
                                   math.atan2(post2[2], post2[1]) - post2[3]))
  end
  -- angle of goal in world
  agoal = util.mod_angle(agoal + imuYaw)
  -- agoal=0 -> yellow;  agoal=pi -> cyan
  if (math.abs(agoal) < goalAngleThres_) then
    -- the goal is yellow
    --     print('------------------ detected goal is the yellow goal ------------------');
    return -1
  elseif (math.abs(mod_angle(math.pi - agoal)) < goalAngleThres_) then
    -- the goal is cyan
    --     print('++++++++++++++++++ detected goal is the cyan goal ++++++++++++++++++');
    return 1
  else
    -- the detected goal posts and goalie do not correlate well
    --     print('==================       detected goal is unknown      ==================');
    return 0
  end
  -- if we make it this far then we do not know which goal it is
  return 0
end

local initialize = function(p0, dp)
  local _p0 = p0 or {0, 0, 0}
  local _dp = dp or {.5 * xMax_, .5 * yMax_, 2 * math.pi}

  xp_ = _p0[1] * vector.ones(n_) + _dp[1] *
            (vector.new(util.randn(n_)) - 0.5 * vector.ones(n_))
  yp_ = _p0[2] * vector.ones(n_) + _dp[2] *
            (vector.new(util.randn(n_)) - 0.5 * vector.ones(n_))
  ap_ = _p0[3] * vector.ones(n_) + _dp[3] *
            (vector.new(util.randu(n_)) - 0.5 * vector.ones(n_))
  wp_ = vector.zeros(n_)
end

local initialize_manual_placement = function(p0, dp)
  local _p0 = p0 or {0, 0, 0}
  local _dp = dp or {.5 * xLineBoundary_, .5 * yLineBoundary_, 2 * math.pi}

  print('re-init partcles for manual placement')
  ap_ = math.atan2(wcm.get_goal_attack()[2], wcm.get_goal_attack()[1]) *
            vector.ones(n_)
  xp_ = wcm.get_goal_defend()[1] / 2 * vector.ones(n_)
  yp_ = _p0[2] * vector.ones(n_) + _dp[2] *
            (vector.new(util.randn(n_)) - 0.5 * vector.ones(n_))
  wp_ = vector.zeros(n_)
end

local initialize_unified = function(p0, p1, dp)
  -- Particle initialization for the same-colored goalpost
  -- Half of the particles at p0
  -- Half of the particles at p1
  local _p0 = p0 or {0, 0, 0}
  p1 = p1 or {0, 0, 0}
  -- Low spread
  local _dp = dp or {.15 * xMax_, .15 * yMax_, math.pi / 6}

  for i = 1, n_ / 2 do
    xp_[i] = _p0[1] + _dp[1] * (math.random() - .5)
    yp_[i] = _p0[2] + _dp[2] * (math.random() - .5)
    ap_[i] = _p0[3] + _dp[3] * (math.random() - .5)

    xp_[i + n_ / 2] = p1[1] + _dp[1] * (math.random() - .5)
    yp_[i + n_ / 2] = p1[2] + _dp[2] * (math.random() - .5)
    ap_[i + n_ / 2] = p1[3] + _dp[3] * (math.random() - .5)
  end
  wp_ = vector.zeros(n_)
end

local initialize_heading = function(aGoal, dp)
  -- Particle initialization at bodySet
  -- When bodySet, all players should face opponents' goal
  -- So reduce weight of  particles that faces our goal
  print('init_heading particles')
  local _dp = dp or {.15 * xMax_, .15 * yMax_, math.pi / 6}
  ap_ = aGoal * vector.ones(n_) + _dp[3] * vector.new(util.randu(n_))
  wp_ = vector.zeros(n_)
end

local reset_heading = function()
  ap_ = 2 * math.pi * vector.new(util.randu(n_))
  wp_ = vector.zeros(n_)
end

local get_pose = function()
  local wmax, imax = max(wp_)
  return xp_[imax], yp_[imax], mod_angle(ap_[imax])
end

local get_sv = function(x0, y0, a0)
  -- weighted sample variance of current particles
  local xs = 0.0
  local ys = 0.0
  local as = 0.0
  local ws = 0.0001

  for i = 1, n_ do
    local dx = x0 - xp_[i]
    local dy = y0 - yp_[i]
    local da = mod_angle(a0 - ap_[i])
    xs = xs + wp_[i] * dx ^ 2
    ys = ys + wp_[i] * dy ^ 2
    as = as + wp_[i] * da ^ 2
    ws = ws + wp_[i]
  end
  return math.sqrt(xs) / ws, math.sqrt(ys) / ws, math.sqrt(as) / ws
end

local landmark_ra = function(xlandmark, ylandmark)
  local r = vector.zeros(n_)
  local a = vector.zeros(n_)
  for i = 1, n_ do
    local dx = xlandmark - xp_[i]
    local dy = ylandmark - yp_[i]
    r[i] = math.sqrt(dx ^ 2 + dy ^ 2)
    a[i] = math.atan2(dy, dx) - ap_[i]
  end
  return r, a
end

local landmark_observation = function(pos, v, rLandmarkFilter, aLandmarkFilter)
  local r = math.sqrt(v[1] ^ 2 + v[2] ^ 2)
  local a = math.atan2(v[2], v[1])
  local rSigma = .15 * r + 0.10
  local aSigma = 5 * math.pi / 180
  local rFilter = rLandmarkFilter or 0.02
  local aFilter = aLandmarkFilter or 0.04

  -- Calculate best matching landmark pos to each particle
  local dxp = {}
  local dyp = {}
  local dap = {}
  for ip = 1, n_ do
    local dx = {}
    local dy = {}
    local dr = {}
    local da = {}
    local err = {}
    for ipos = 1, #pos do
      dx[ipos] = pos[ipos][1] - xp_[ip]
      dy[ipos] = pos[ipos][2] - yp_[ip]
      dr[ipos] = math.sqrt(dx[ipos] ^ 2 + dy[ipos] ^ 2) - r
      da[ipos] = mod_angle(math.atan2(dy[ipos], dx[ipos]) - (ap_[ip] + a))
      err[ipos] = (dr[ipos] / rSigma) ^ 2 + (da[ipos] / aSigma) ^ 2
    end
    local errMin, imin = min(err)

    -- Update particle weights:
    wp_[ip] = wp_[ip] - errMin

    dxp[ip] = dx[imin]
    dyp[ip] = dy[imin]
    dap[ip] = da[imin]
  end
  -- Filter toward best matching landmark position:
  for ip = 1, n_ do
    --  print(string.format("%d %.1f %.1f %.1f %.1f %.1f %.1f",ip,xp_[ip],yp_[ip],ap_[ip],dxp[ip],dyp[ip],dap[ip]));
    --  print(string.format("%d %.1f %.1f %.1f",ip,xp_[ip],yp_[ip],ap_[ip]));
    --  print(string.format("%.1f %.1f %.1f",dap[ip],dyp[ip],dxp[ip]));
    xp_[ip] = xp_[ip] + rFilter * (dxp[ip] - r * math.cos(ap_[ip] + a))
    yp_[ip] = yp_[ip] + rFilter * (dyp[ip] - r * math.sin(ap_[ip] + a))
    ap_[ip] = ap_[ip] + aFilter * dap[ip]

    -- check boundary
    xp_[ip] = math.min(xMax_, math.max(-xMax_, xp_[ip]))
    yp_[ip] = math.min(yMax_, math.max(-yMax_, yp_[ip]))
  end
end

local corner_observation = function(v, rCornerFilter, aCornerFilter)
  local r = math.sqrt(v[1] ^ 2 + v[2] ^ 2)
  local a = math.atan2(v[2], v[1])
  local rSigma = .15 * r + 0.10
  local aSigma = 5 * math.pi / 180
  local rFilter = rCornerFilter or 0.02
  local aFilter = aCornerFilter or 0.04

  -- Calculate best matching landmark pos to each particle
  for ip = 1, n_ do
    local dr = {}
    local da = {}
    local err = {}
    local ix = math.floor((xp_[ip] + 3) * 10) + 1
    local iy = math.floor((yp_[ip] + 3) * 10) + 1
    ix = math.min(60, math.max(ix, 1))
    iy = math.min(40, math.max(iy, 1))
    for ipos = 1, #Lcorner_ do
      dr[ipos] = corner_lut_r_[ix][iy][ipos] - r
      da[ipos] = mod_angle(corner_lut_a_[ix][iy][ipos] - (a + ap_[ip]))
      err[ipos] = (dr[ipos] / rSigma) ^ 2 + (da[ipos] / aSigma) ^ 2
    end
    local errMin, imin = min(err)

    -- Update particle weights:
    xp_[ip] = xp_[ip] + rFilter *
                  (Lcorner_[imin][1] - xp_[ip] - r * math.cos(ap_[ip] + a))
    yp_[ip] = yp_[ip] + rFilter *
                  (Lcorner_[imin][2] - yp_[ip] - r * math.sin(ap_[ip] + a))
    ap_[ip] = ap_[ip] + aFilter * da[imin]
    wp_[ip] = wp_[ip] - errMin

    -- check boundary
    xp_[ip] = math.min(xMax_, math.max(-xMax_, xp_[ip]))
    yp_[ip] = math.min(yMax_, math.max(-yMax_, yp_[ip]))
  end
end

---------------------------------------------------------------------------
-- Now we have two ambiguous goals to check
-- So we separate the triangulation part and the update part
---------------------------------------------------------------------------
local triangulate = function(pos, v)
  -- Based on old code

  -- Use angle between posts (most accurate)
  -- as well as combination of post distances to triangulate
  local aPost = {}
  aPost[1] = math.atan2(v[1][2], v[1][1])
  aPost[2] = math.atan2(v[2][2], v[2][1])
  local daPost = mod_angle(aPost[1] - aPost[2])

  -- Radius of circumscribing circle
  local sa = math.sin(math.abs(daPost))
  local ca = math.cos(daPost)
  local rCircumscribe = goalWidth_ / (2 * sa)

  -- Post distances
  local d2Post = {}
  d2Post[1] = v[1][1] ^ 2 + v[1][2] ^ 2
  d2Post[2] = v[2][1] ^ 2 + v[2][2] ^ 2
  local ignore, iMin = min(d2Post)

  -- Position relative to center of goal:
  local sumD2 = d2Post[1] + d2Post[2]
  local dGoal = math.sqrt(.5 * sumD2)
  local dx = (sumD2 - goalWidth_ ^ 2) / (4 * rCircumscribe * ca)
  local dy = math.sqrt(math.max(.5 * sumD2 - .25 * goalWidth_ ^ 2 - dx ^ 2, 0))

  -- Predicted pose:
  local x = pos[iMin][1]
  x = x - sign(x) * dx
  local y = pos[iMin][2]
  y = sign(y) * dy
  local a = math.atan2(pos[iMin][2] - y, pos[iMin][1] - x) - aPost[iMin]

  local pose = {}
  pose.x = x
  pose.y = y
  pose.a = a

  local aGoal = util.mod_angle((aPost[1] + aPost[2]) / 2)

  return pose, dGoal, aGoal
end

local triangulate2 = function(pos, v)
  -- New code (for OP)
  local aPost = {}
  local d2Post = {}

  aPost[1] = math.atan2(v[1][2], v[1][1])
  aPost[2] = math.atan2(v[2][2], v[2][1])
  d2Post[1] = v[1][1] ^ 2 + v[1][2] ^ 2
  d2Post[2] = v[2][1] ^ 2 + v[2][2] ^ 2
  local d1 = math.sqrt(d2Post[1])
  local d2 = math.sqrt(d2Post[2])

  vcm.add_debug_message(string.format(
                            "===\n World: triangulation 2\nGoal dist: %.1f / %.1f\nGoal width: %.1f\n",
                            d1, d2, goalWidth_))

  vcm.add_debug_message(string.format("Measured goal width: %.1f\n", math.sqrt(
                                          (v[1][1] - v[2][1]) ^ 2 +
                                              (v[1][2] - v[2][2]) ^ 2)))
  -- SJ: still testing
  -- local postfix=1;
  local postfix = 0
  if postfix > 0 then
    if d1 > d2 then
      -- left post correction based on right post
      -- v1=kcos(a1),ksin(a1)
      -- k^2 - 2k(v[2][1]cos(a1)+v[2][2]sin(a1)) + d2Post[2]-goalWidth_^2 = 0
      local ca = math.cos(aPost[1])
      local sa = math.sin(aPost[1])
      local b = v[2][1] * ca + v[2][2] * sa
      local c = d2Post[2] - goalWidth_ ^ 2

      if b * b - c > 0 then
        vcm.add_debug_message("Correcting left post\n")
        vcm.add_debug_message(string.format("Left post angle: %d\n",
                                            aPost[1] * 180 / math.pi))

        local k1 = b - math.sqrt(b * b - c)
        local k2 = b + math.sqrt(b * b - c)
        vcm.add_debug_message(string.format("d1: %.1f v1: %.1f %.1f\n", d1,
                                            v[1][1], v[1][2]))
        vcm.add_debug_message(string.format("k1: %.1f v1_1: %.1f %.1f\n", k1,
                                            k1 * ca, k1 * sa))
        vcm.add_debug_message(string.format("k2: %.1f v1_2: %.1f %.1f\n", k2,
                                            k2 * ca, k2 * sa))
        if math.abs(d2 - k1) < math.abs(d2 - k2) then
          v[1][1], v[1][2] = k1 * ca, k1 * sa
        else
          v[1][1], v[1][2] = k2 * ca, k2 * sa
        end
      end
    else
      -- right post correction based on left post
      -- v2=kcos(a2),ksin(a2)
      -- k^2 - 2k(v[1][1]cos(a2)+v[1][2]sin(a2)) + d2Post[1]-goalWidth_^2 = 0
      local ca = math.cos(aPost[2])
      local sa = math.sin(aPost[2])
      local b = v[1][1] * ca + v[1][2] * sa
      local c = d2Post[1] - goalWidth_ ^ 2

      if b * b - c > 0 then
        local k1 = b - math.sqrt(b * b - c)
        local k2 = b + math.sqrt(b * b - c)
        vcm.add_debug_message(string.format("d2: %.1f v2: %.1f %.1f\n", d2,
                                            v[2][1], v[2][2]))
        vcm.add_debug_message(string.format("k1: %.1f v2_1: %.1f %.1f\n", k1,
                                            k1 * ca, k1 * sa))
        vcm.add_debug_message(string.format("k2: %.1f v2_2: %.1f %.1f\n", k2,
                                            k2 * ca, k2 * sa))
        if math.abs(d2 - k1) < math.abs(d2 - k2) then
          v[2][1], v[2][2] = k1 * ca, k1 * sa
        else
          v[2][1], v[2][2] = k2 * ca, k2 * sa
        end
      end
    end
  end

  -- Use center of the post to fix angle
  local vGoalX = 0.5 * (v[1][1] + v[2][1])
  local vGoalY = 0.5 * (v[1][2] + v[2][2])
  local rGoal = math.sqrt(vGoalX ^ 2 + vGoalY ^ 2)

  local aGoal = 0
  if aPost[1] < aPost[2] then
    aGoal = -math.atan2(v[1][1] - v[2][1], -(v[1][2] - v[2][2]))
  else
    aGoal = -math.atan2(v[2][1] - v[1][1], -(v[2][2] - v[1][2]))
  end

  local ca = math.cos(aGoal)
  local sa = math.sin(aGoal)

  local dx = ca * vGoalX - sa * vGoalY
  local dy = sa * vGoalX + ca * vGoalY

  local x0 = 0.5 * (pos[1][1] + pos[2][1])
  local y0 = 0.5 * (pos[1][2] + pos[2][2])

  local x = x0 - sign(x0) * dx
  local y = -sign(x0) * dy
  local a = aGoal
  if x0 < 0 then
    a = mod_angle(a + math.pi)
  end
  local dGoal = rGoal

  local pose = {}
  pose.x = x
  pose.y = y
  pose.a = a
  -- aGoal = util.mod_angle((aPost[1]+aPost[2])/2);
  return pose, dGoal, aGoal
end

local goal_observation = function(pos, v)
  -- Get estimate using triangulation
  local pose, dGoal, aGoal
  if use_new_goalposts_ == 1 then
    pose, dGoal, aGoal = triangulate2(pos, v)
  else
    pose, dGoal, aGoal = triangulate(pos, v)
  end

  local x, y, a = pose.x, pose.y, pose.a

  local rSigma = .25 * dGoal + 0.20
  local aSigma = 5 * math.pi / 180
  local rFilter = rKnownGoalFilter_
  local aFilter = aKnownGoalFilter_

  -- SJ: testing
  triangulation_threshold = 4.0

  if dGoal < triangulation_threshold then
    for ip = 1, n_ do
      local xErr = x - xp_[ip]
      local yErr = y - yp_[ip]
      local rErr = math.sqrt(xErr ^ 2 + yErr ^ 2)
      local aErr = mod_angle(a - ap_[ip])
      local err = (rErr / rSigma) ^ 2 + (aErr / aSigma) ^ 2
      wp_[ip] = wp_[ip] - err

      -- Filter towards goal:
      xp_[ip] = xp_[ip] + rFilter * xErr
      yp_[ip] = yp_[ip] + rFilter * yErr
      ap_[ip] = ap_[ip] + aFilter * aErr
    end
  else
    -- Don't use triangulation for far goals
    local goalpos = {{(pos[1][1] + pos[2][1]) / 2, (pos[1][2] + pos[2][2]) / 2}}
    local goalv = {(v[1][1] + v[2][1]) / 2, (v[1][2] + v[2][2]) / 2}
    landmark_observation(goalpos, goalv, rKnownGoalFilter_, aKnownGoalFilter_)
  end
end

local goal_observation_unified = function(pos1, pos2, v)
  vcm.add_debug_message("World: Ambiguous two posts")

  -- Get pose estimate from two goalpost locations
  local pose1, pose2, dGoal1, dGoal2
  if use_new_goalposts_ == 1 then
    pose1, dGoal1 = triangulate2(pos1, v)
    pose2, dGoal2 = triangulate2(pos2, v)
  else
    pose1, dGoal1 = triangulate(pos1, v)
    pose2, dGoal2 = triangulate(pos2, v)
  end

  local x1, y1, a1 = pose1.x, pose1.y, pose1.a
  local x2, y2, a2 = pose2.x, pose2.y, pose2.a

  local rSigma1 = .25 * dGoal1 + 0.20
  local rSigma2 = .25 * dGoal2 + 0.20
  local aSigma = 5 * math.pi / 180
  local rFilter = rUnknownGoalFilter_
  local aFilter = aUnknownGoalFilter_

  for ip = 1, n_ do
    local xErr1 = x1 - xp_[ip]
    local yErr1 = y1 - yp_[ip]
    local rErr1 = math.sqrt(xErr1 ^ 2 + yErr1 ^ 2)
    local aErr1 = mod_angle(a1 - ap_[ip])
    local err1 = (rErr1 / rSigma1) ^ 2 + (aErr1 / aSigma) ^ 2

    local xErr2 = x2 - xp_[ip]
    local yErr2 = y2 - yp_[ip]
    local rErr2 = math.sqrt(xErr2 ^ 2 + yErr2 ^ 2)
    local aErr2 = mod_angle(a2 - ap_[ip])
    local err2 = (rErr2 / rSigma2) ^ 2 + (aErr2 / aSigma) ^ 2

    -- Filter towards best matching goal:
    if err1 > err2 then
      wp_[ip] = wp_[ip] - err2
      xp_[ip] = xp_[ip] + rFilter * xErr2
      yp_[ip] = yp_[ip] + rFilter * yErr2
      ap_[ip] = ap_[ip] + aFilter * aErr2
    else
      wp_[ip] = wp_[ip] - err1
      xp_[ip] = xp_[ip] + rFilter * xErr1
      yp_[ip] = yp_[ip] + rFilter * yErr1
      ap_[ip] = ap_[ip] + aFilter * aErr1
    end
  end
end

local goal_yellow = function(v)
  goal_observation(postYellow_, v)
end

local goal_cyan = function(v)
  goal_observation(postCyan_, v)
end

local post_yellow_unknown = function(v)
  landmark_observation(postYellow_, v[1], rKnownPostFilter_, aKnownPostFilter_)
end

local post_yellow_left = function(v)
  landmark_observation({postYellow_[1]}, v[1], rKnownPostFilter_,
                       aKnownPostFilter_)
end

local post_yellow_right = function(v)
  landmark_observation({postYellow_[2]}, v[1], rKnownPostFilter_,
                       aKnownPostFilter_)
end

local post_cyan_unknown = function(v)
  landmark_observation(postCyan_, v[1], rKnownPostFilter_, aKnownPostFilter_)
end

local post_cyan_left = function(v)
  landmark_observation({postCyan_[1]}, v[1], rKnownPostFilter_,
                       aKnownPostFilter_)
end

local post_cyan_right = function(v)
  landmark_observation({postCyan_[2]}, v[1], rKnownPostFilter_,
                       aKnownPostFilter_)
end

local post_unified_unknown = function(v)
  landmark_observation(postUnified_, v[1], rUnknownPostFilter_,
                       aUnknownPostFilter_)
end

local post_unified_left = function(v)
  landmark_observation(postLeft_, v[1], rUnknownPostFilter_, aUnknownPostFilter_)
end

local post_unified_right = function(v)
  landmark_observation(postRight_, v[1], rUnknownPostFilter_,
                       aUnknownPostFilter_)
end

local goal_unified = function(v)
  goal_observation_unified(postCyan_, postYellow_, v)
end

local landmark_cyan = function(v)
  landmark_observation({landmarkCyan_}, v, rLandmarkFilter_, aLandmarkFilter_)
end

local landmark_yellow = function(v)
  landmark_observation({landmarkYellow_}, v, rLandmarkFilter_, aLandmarkFilter_)
end

local corner = function(v) -- corner(v,a)
  --  print(Lcorner_,v,rCornerFilter_,aCornerFilter_);
  --  landmark_observation(Lcorner_,v,rCornerFilter_,aCornerFilter_);
  corner_observation(v, rCornerFilter_, aCornerFilter_)
  --  line(v,a);--Fix heading
end

local line = function(v, a)
  -- line center
  local x = v[1]
  local y = v[2]
  local r = math.sqrt(x ^ 2 + y ^ 2)

  local w0 = .25 / (1 + r / 2.0)

  -- TODO: wrap in loop for lua
  for ip = 1, n_ do
    -- pre-compute sin/cos of orientations
    local ca = math.cos(ap_[ip])
    local sa = math.sin(ap_[ip])

    -- compute line weight
    local wLine = w0 * (math.cos(4 * (ap_[ip] + a)) - 1)
    wp_[ip] = wp_[ip] + wLine

    local xGlobal = v[1] * ca - v[2] * sa + xp_[ip]
    local yGlobal = v[1] * sa + v[2] * ca + yp_[ip]

    local wBounds = math.max(xGlobal - xLineBoundary_, 0) +
                        math.max(-xGlobal - xLineBoundary_, 0) +
                        math.max(yGlobal - yLineBoundary_, 0) +
                        math.max(-yGlobal - yLineBoundary_, 0)
    wp_[ip] = wp_[ip] - (wBounds / .20)
  end
end

local imuYaw_update = function(a)
  local aSigma = 15 * math.pi / 180
  local aFilter = aImuYawFilter_ or 0.05
  for ip = 1, n_ do
    local da = mod_angle(a - ap_[ip])
    local err = (da / aSigma) ^ 2
    wp_[ip] = wp_[ip] - err
    -- Filter toward best matching landmark position:
    -- print(string.format("%d %.1f %.1f %.1f",ip,xp_[ip],yp_[ip],ap_[ip]));
    ap_[ip] = ap_[ip] + aFilter * da
  end
end

local odometry = function(dx, dy, da)
  for ip = 1, n_ do
    local ca = math.cos(ap_[ip])
    local sa = math.sin(ap_[ip])
    xp_[ip] = xp_[ip] + dx * ca - dy * sa
    yp_[ip] = yp_[ip] + dx * sa + dy * ca
    ap_[ip] = ap_[ip] + da
  end
end

local zero_pose = function()
  xp_ = vector.zeros(n_)
  yp_ = vector.zeros(n_)
  ap_ = vector.zeros(n_)
end
return {
  mod_angle = mod_angle,
  add_noise = add_noise,
  resample = resample,
  corner_init = corner_init,
  imuGoal = imuGoal,
  initialize = initialize,
  initialize_manual_placement = initialize_manual_placement,
  initialize_unified = initialize_unified,
  initialize_heading = initialize_heading,
  reset_heading = reset_heading,
  get_pose = get_pose,
  get_sv = get_sv,
  landmark_ra = landmark_ra,
  landmark_observation = landmark_observation,
  corner_observation = corner_observation,
  triangulate = triangulate,
  triangulate2 = triangulate2,
  goal_observation = goal_observation,
  goal_observation_unified = goal_observation_unified,
  goal_yellow = goal_yellow,
  goal_cyan = goal_cyan,
  post_yellow_unknown = post_yellow_unknown,
  post_yellow_left = post_yellow_left,
  post_yellow_right = post_yellow_right,
  post_cyan_unknown = post_cyan_unknown,
  post_cyan_left = post_cyan_left,
  post_cyan_right = post_cyan_right,
  post_unified_unknown = post_unified_unknown,
  post_unified_left = post_unified_left,
  post_unified_right = post_unified_right,
  goal_unified = goal_unified,
  landmark_cyan = landmark_cyan,
  landmark_yellow = landmark_yellow,
  corner = corner,
  line = line,
  imuYaw_update = imuYaw_update,
  odometry = odometry,
  zero_pose = zero_pose,

  postCyan = postCyan,
  postYellow = postYellow,
  xp = xp,
  yp = yp,
  ap = ap,
  wp = wp,
}

