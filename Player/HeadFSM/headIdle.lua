local _NAME = "headIdle";

local Body = require('Body')
local vcm = require('vcm')
local mcm = require('mcm')
local vector = require('vector')

local t0_ = 0;

local entry = function()
  print("HeadFSM: ".._NAME.." entry");
  local pitchBias = mcm.get_headPitchBias();--robot specific head bias
  t0_ = Body.get_time();

  -- set head to default position
  local yaw = 0;
  local pitch = 20*math.pi/180;

  Body.set_head_command({yaw, pitch-pitchBias});
  Body.set_para_headpos(vector.new({yaw, pitch-pitchBias}));--123456î^²¿
  Body.set_state_headValid(1);---123456î^²¿

  -- continuously switch cameras
  vcm.set_camera_command(-1);
end

local update = function()
end

local exit = function()
end

return {
  _NAME = _NAME,
  entry = entry,
  update = update,
  exit = exit,
};
