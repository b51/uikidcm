cwd = os.getenv('PWD')
package.cpath = cwd .. "/Lib/?.so;" .. package.cpath
package.path = cwd .. "/Util/?.lua;" .. package.path
package.path = cwd .. "/Config/?.lua;" .. package.path
package.path = cwd .. "/Lib/?.lua;" .. package.path
package.path = cwd .. "/Dev/?.lua;" .. package.path
package.path = cwd .. "/World/?.lua;" .. package.path
package.path = cwd .. "/Vision/?.lua;" .. package.path
package.path = cwd .. "/Motion/?.lua;" .. package.path

local unix = require('unix')
local vcm = require('vcm')
local gcm = require('gcm')
local wcm = require('wcm')
local mcm = require('mcm')
local Body = require('Body')
local Vision = require('Vision')
local World = require('World')
local Team, GameControl, Broadcast

local comm_inited_ = false

-- TODO(b51): set camera broadcast with resized rgb

vcm.set_camera_teambroadcast(1)
vcm.set_camera_broadcast(0)
-- Now vcm.get_camera_teambroadcast() determines
-- Whether we use wired monitoring comm or wireless team comm

local count_ = 0
local nProcessedImages_ = 0
local tUpdate_ = unix.time()

local broadcast = function()
  local broadcast_enable = vcm.get_camera_broadcast()
  local imgRate = 1
  if broadcast_enable > 0 then
    if broadcast_enable == 1 then
      -- Mode 1, send 1/4 resolution, labeB, all info
      imgRate = 1 -- 30fps
    elseif broadcast_enable == 2 then
      -- Mode 2, send 1/2 resolution, labeA, labelB, all info
      imgRate = 2 -- 15fps
    else
      -- Mode 3, send 1/2 resolution, info for logging
      imgRate = 1 -- 30fps
    end
    -- Always send non-image data
    Broadcast.update(broadcast_enable)
    -- Send image data every so often
    if nProcessedImages_ % imgRate == 0 then
      Broadcast.update_img(broadcast_enable)
    end
    -- Reset this flag at every broadcast
    -- To prevent monitor running during actual game
    -- vcm.set_camera_broadcast(0);
  end
end

local entry = function()
  World.entry()
  Vision.entry()
end

local update = function()
  count_ = count_ + 1
  --  print("imuangle :",Body.get_sensor_imuAngle()[3]*180/math.pi);
  local tstart = unix.time()

  -- update vision
  local imageProcessed = Vision.update()
  World.update_odometry()

  -- update localization
  if imageProcessed then
    nProcessedImages_ = nProcessedImages_ + 1
    World.update_vision()

    if (nProcessedImages_ % 200 == 0) then
      print('fps: ' .. (200 / (unix.time() - tUpdate_)))
      tUpdate_ = unix.time()
    end
  end

  if not comm_inited_ and
      (vcm.get_camera_broadcast() > 0 or vcm.get_camera_teambroadcast() > 0) then
    if vcm.get_camera_teambroadcast() > 0 then
      Team = require('Team')
      GameControl = require('GameControl')
      Team.entry()
      GameControl.entry()
      print("Starting to send wireless team message..")
    else
      Broadcast = require('Broadcast')
      print("Starting to send wired monitor message..")
    end
    comm_inited_ = true
  end

  if comm_inited_ and imageProcessed then
    if vcm.get_camera_teambroadcast() > 0 then
      GameControl.update()
      if nProcessedImages_ % 3 == 0 then
        -- 10 fps team update
        Team.update()
      end
    else
      broadcast()
    end
  end
end

-- exit
local exit = function()
  if vcm.get_camera_teambroadcast() > 0 then
    Team.exit()
    GameControl.exit()
  end
  Vision.exit()
  World.exit()
end

return {
  entry = entry,
  update = update,
  exit = exit,
  broadcast = broadcast,
}

