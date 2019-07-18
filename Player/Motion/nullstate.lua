local entry = function()
  print("Motion: nullstate entry");
end

local update = function()
end

local exit = function()
end

return {
  _NAME = "nullstate",
  entry = entry,
  update = update,
  exit = exit,
};
