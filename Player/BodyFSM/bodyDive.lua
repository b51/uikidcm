local _NAME = "bodyDive";
local Body = require('Body')
local vector = require('vector')
local Config = require('Config')
local Motion = require('Motion');

-- This is a dummy state that just recovers from a dive
-- and catches the case when it never ends up falling...
local t0 = 0;
local goalie_dive = Config.goalie_dive or 0;
local timeout;
if goalie_dive==1 then --arm motion only
  timeout = 2.0;
else
  timeout = 6.0;
end

local entry = function()
  print("bodyFSM: ".._NAME.." entry");
  t0 = Body.get_time();
end

local update = function()
  local t = Body.get_time();
  if (t - t0 > timeout) then
    if goalie_dive==1 then --arm motion only
      return "reanticipate"; --Quick timeout
    else
      return "timeout";
    end
  end
end

local exit = function()
end

return {
  _NAME = _NAME,
  entry = entry,
  update = update,
  exit = exit,
};
