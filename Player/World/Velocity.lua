local Config = require('Config')
local vector = require('vector')
local Body = require('Body')
local gcm = require('gcm')

local ball_log_index_ = 1
local ball_logs_ = {}
local ball_log_count_ = 0

-------------------------------
-- A very simple velocity filter
-------------------------------
local noball_count_ = 1
local ball_count_ = 0
-- If ball is not seen for this # of frames, remove ball memory
local noball_threshold_ = 5
-- How many succeding ball observations is needed before updating?
-- We need at least two observation to update velocity
local ball_threshold_ = 2

local gamma_ = 0.3
local discount_ = 0.8

local max_distance_ = 4.0 -- Only check velocity within this radius
local max_velocity_ = 4.0 -- Ignore if velocity exceeds this

local oldx_, oldy_ = 0, 0
local olda_, oldR_ = 0, 0
local newA_, newR_ = 0, 0

-- Now we maintain a cue of ball distance
-- Current ball distance is the minimum one
local ballR_cue_length_ = 10
local ballR_cue_ = vector.zeros(ballR_cue_length_)
local ballR_index = 1
local min_ballR_old_ = 0
local role_ = gcm.get_team_role()
local vx_, vy_, isdodge_ = 0, 0, 0
local t0 = Body.get_time()
local tLast_ = Body.get_time()

local goalie_log_balls_ = Config.goalie_log_balls or 0

local add_log = function(x, y, vx, vy)
  if role_ ~= 0 or goalie_log_balls_ == 0 then
    return
  end

  local log = {}
  if ball_log_count_ == 0 then
    t0 = Body.get_time()
  end

  ball_log_count_ = ball_log_count_ + 1
  log.time = Body.get_time() - t0
  log.ballxy = {x, y}
  log.ballvxy = {vx, vy}
  ball_logs_[ball_log_count_] = log
end

local flush_log = function()
  if role_ ~= 0 or goalie_log_balls_ == 0 then
    return
  end

  local filename = string.format("./Data/balllog%d.txt", ball_log_index_)
  local outfile = assert(io.open(filename, "w"))

  local data = ""
  for i = 1, ball_log_count_ do
    data = data ..
               string.format("%.2f %.2f %.2f %.2f %.2f\n", ball_logs_[i].time,
                             ball_logs_[i].ballxy[1], ball_logs_[i].ballxy[2],
                             ball_logs_[i].ballvxy[1], ball_logs_[i].ballvxy[2])
  end

  outfile:write(data)
  outfile:flush()
  outfile:close()

  ball_logs_ = {}
  ball_log_count_ = 0
  ball_log_index_ = ball_log_index_ + 1
end

local entry = function()
  oldx_, oldy_, vx_, vy_, isdodge_ = 0, 0, 0, 0, 0
  t0 = Body.get_time()
  tLast_ = Body.get_time()
  noball_count_ = 1
end

local update = function(newx, newy)
  local t = Body.get_time()
  ball_count_ = ball_count_ + 1
  local ballR = math.sqrt(newx ^ 2 + newy ^ 2)
  local ballA = math.atan2(newy, newx)

  -- Lower gamma if head not locked on at the ball
  local locked_on = wcm.get_ball_locked_on()
  if locked_on == 0 then
    -- vx_,vy=0,0;
  end

  -- Ball seen for some continuous frames
  if t > tLast_ and ball_count_ >= ball_threshold_ then
    local tPassed = t - tLast_
    local moveR = ((oldx_ - newx) ^ 2 + (oldy_ - newy) ^ 2)
    local th = ballR * 0.05
    if ballR > 2.0 then
      th = th * 2
    end
    if ballR > 3.0 then
      vx_, vy_ = 0, 0
      oldx_ = newx
      oldy_ = newy
      tLast_ = t
    elseif moveR > th then
      local vxCurrent = (newx - oldx_) / tPassed
      local vyCurrent = (newy - oldy_) / tPassed
      local vmagCurrent = math.sqrt(vxCurrent ^ 2 + vyCurrent ^ 2)

      if vmagCurrent < 4.0 then -- don't update if outlier
        vx_ = (1 - gamma_) * vx_ + gamma_ * vxCurrent
        vy_ = (1 - gamma_) * vy_ + gamma_ * vyCurrent
        oldx_ = newx
        oldy_ = newy
        tLast_ = t
      end
    else
      vx_ = vx_ * discount_
      vy_ = vy_ * discount_
      tLast_ = t
    end
  else
    -- Ball first seen, don't update velocity
    vx_ = 0
    vy_ = 0
    -- Update position
    oldx_ = newx
    oldy_ = newy
    tLast_ = t
    noball_count_ = 0
  end

  local vMag = math.sqrt(vx_ ^ 2 + vy_ ^ 2)

  local vR = 0.8
  add_log(newx, newy, vx_, vy_)

  --[[
  if vx_<-vR and vMag > vR then
    print(string.format("BX  %.2f V %.2f====", newx,vx_));
  else
    print(string.format("BX  %.2f V %.2f", newx,vx_));
  end
--]]
end

local update_noball = function()
  ball_count_ = 0
  noball_count_ = noball_count_ + 1
  -- Reset velocity if ball was not seen
  if noball_count_ == noball_threshold_ then
    print("Velocity resetted")
    vx_ = 0
    vy_ = 0
    ballR_cue_ = vector.zeros(ballR_cue_length_)
    min_ballR_old_ = 0
    oldx_, oldy_ = 0, 0
    flush_log()
  else
    vx_ = gamma_ * vx_
    vy_ = gamma_ * vy_
  end
end

local getVelocity = function()
  return vx_, vy_, isdodge_
end

return {
  add_log = add_log,
  flush_log = flush_log,
  entry = entry,
  update = update,
  update_noball = update_noball,
  getVelocity = getVelocity,
}

