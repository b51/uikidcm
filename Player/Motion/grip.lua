-- Stabilized grip motion state
-- by SJ, edited by Steve

local util = require('util')
local vector = require('vector')
local Config = require('Config')
local Body = require('Body')
local keyframe = require('keyframe')
local walk = require('walk')

local started = false;
local active = true;
local t0 = Body.get_time();

-- TODO(b51): this is used for technical challenge to grap a ball,
--            deprecate op grip and re-add MOS gait in future

local entry = function()
  print("Motion: grip entry");
  walk.stop();
  started = false;
  active = true;
end

local update = function()
  if (not started and walk.active) then
    walk.update();
    return;
  elseif not started then
    started=true;
    t0 = Body.get_time();
  end
  local t=Body.get_time();
  t=t-t0;
  return "done";
end

local exit = function()
  print("Pickup exit");
  active = false;
  walk.active = true;
end

return {
  _NAME = "grip",
  entry = entry,
  update = update,
  exit = exit,
};
