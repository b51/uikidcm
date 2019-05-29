module(... or "", package.seeall)

require('dlcognition')

maxFPS = Config.vision.maxFPS;
tperiod = 1.0/maxFPS;

dlcognition.entry();

while (true) do
  tstart = unix.time();

  dlcognition.update();

  tloop = unix.time() - tstart;

  if (tloop < tperiod) then
    unix.usleep((tperiod - tloop)*(1E6));
  end
end

dlcognition.exit();

