local _NAME = "bodyReady";
local Body = require('Body')
local wcm = require('wcm')
local gcm = require('gcm')
local util = require('util')
local vector = require('vector')
local Config = require('Config')
local Team = require('Team')
local walk = require('walk')

local entry = function()
  print("BodyFSM: ".._NAME.." entry");
  Motion.event('standup')
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
