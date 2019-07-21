local _NAME = "headStart"

local Body = require('Body')

local entry = function()
  print("HeadFSM: ".._NAME.." entry");
end

local update = function()
  return 'done';
end

local exit = function()
end

return {
  _NAME = _NAME,
  entry = entry,
  update = update,
  exit = exit,
};
