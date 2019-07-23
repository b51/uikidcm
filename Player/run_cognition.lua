package.cpath = './Lib/?.so;' .. package.cpath
package.path = './Util/?.lua;' .. package.path
package.path = './Config/?.lua;' .. package.path

local Config = require('Config')
local cognition = require('cognition')

local maxFPS_ = Config.vision.maxFPS
local tperiod_ = 1.0 / maxFPS_

cognition.entry()

while (true) do
  local tstart = unix.time()

  cognition.update()

  local tloop = unix.time() - tstart

  if (tloop < tperiod_) then
    unix.usleep((tperiod_ - tloop) * (1E6))
  end
end

cognition.exit()

