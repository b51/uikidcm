local vector = require('vector')
local Body = require('Body')
local Config = require('Config')
local keyframe = require('keyframe')
local walk = require('walk')

-- default kick type
local diveType = "diveLeft";
local goalie_dive = Config.goalie_dive or 0;
local t0 = Body.get_time();
local phase = 1;
--How long does goalie lie down?
local tDelay = Config.goalie_dive_waittime or 3.0;

local dosquat = function()
-- TODO(b51): Merge all delay time to one
  local t = Body.get_time();
  local divedone=false;
  Body.set_para_headpos(vector.new({0,0}));  --tse
  Body.set_state_headValid(1);               --tse

  print("do diveCenter Start");
  Body.set_para_gaitID(vector.new({7,1}));  --------- 调用diveCeter
  Body.set_state_specialValid(1);  ------------------ 执行start

  if (t - t0 > tDelay) then
    divedone=true;
  end
  return divedone;
end

local dodive = function()
  if diveType == "diveCenter" then
    --print("do diveCenter");
    return dosquat();
  end
  t = Body.get_time();
  local divedone=false;
  --raise hand. squat down
  if diveType == "diveLeft" then
    Body.set_para_headpos(vector.new({0,0}));  --tse
    Body.set_state_headValid(1);               --tse
    Body.set_para_gaitID(vector.new({5,1}));  --------- 调用diveCeter
    Body.set_state_specialValid(1);  ------------------ 执行start
  else
    --print("do diveRight PH1");
    Body.set_para_headpos(vector.new({0,0}));  --tse
    Body.set_state_headValid(1);               --tse
    Body.set_para_gaitID(vector.new({6,1}));  --------- 调用diveCeter
    Body.set_state_specialValid(1);  ------------------ 执行start
  end

  if t - t0 > tDelay then
    print("diveDone")
    divedone=true;
  end
  return divedone;
end

local dodive2 = function()
  local t = Body.get_time();
  local divedone = false;
  if t - t0 > tDelay then
     divedone = true;
  end
  return divedone;
end

local entry = function()
  print("Motion: dive entry");
  walk.active=false; --Instaneous walk stop
  --The robot should stand still before dive anyway
  t0 = Body.get_time();
end

local update = function()
  local divedone = false;
  if goalie_dive==2 then --Diving
    divedone=dodive();
    if divedone then
      if diveType == "diveCenter" then
        --walk.start();    -tse
        return "done"
      else
        return "divedone"
      end
    end
  else --Arm motion
    divedone=dodive2();
    if divedone then
      walk.start();
      return "done"
    end
  end
end

local exit = function()
end

local set_dive = function(newdive)
  -- set dive type (left/right)
  diveType = newdive;
end

return {
  _NAME = "dive",
  entry = entry,
  update = update,
  exit = exit,
  set_dive = set_dive,
};
