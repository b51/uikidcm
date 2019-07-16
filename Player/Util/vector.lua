local mt = {};

local new = function(t)
  t = t or {};
  return setmetatable(t, mt);
end

local ones = function(n)
  n = n or 1;
  local t = {};
  for i = 1, n do
    t[i] = 1;
  end
  return setmetatable(t, mt);
end

local zeros = function(n)
  n = n or 1;
  local t = {};
  for i = 1, n do
    t[i] = 0;
  end
  return setmetatable(t, mt);
end

local slice = function(v1, istart, iend)
  local v = {};
  iend = iend or #v1;
  for i = 1,iend-istart+1 do
    v[i] = v1[istart+i-1];
  end
  return setmetatable(v, mt);
end

local add = function(v1, v2)
  local v = {};
  for i = 1, #v1 do
    v[i] = v1[i] + v2[i];
  end
  return setmetatable(v, mt);
end

local sub = function(v1, v2)
  local v = {};
  for i = 1, #v1 do
    v[i] = v1[i] - v2[i];
  end
  return setmetatable(v, mt);
end

local mulnum = function(v1, a)
  local v = {};
  for i = 1, #v1 do
    v[i] = a * v1[i];
  end
  return setmetatable(v, mt);
end

local divnum = function(v1, a)
  local v = {};
  for i = 1, #v1 do
    v[i] = v1[i]/a;
  end
  return setmetatable(v, mt);
end

local mul = function(v1, v2)
  if type(v2) == "number" then
    return mulnum(v1, v2);
  elseif type(v1) == "number" then
    return mulnum(v2, v1);
  else
    local s = 0;
    for i = 1, #v1 do
      s = s + v1[i] * v2[i];
    end
    return s;
  end
end

local unm = function(v1)
  return mulnum(v1, -1);
end

local div = function(v1, v2)
  if type(v2) == "number" then
    return divnum(v1, v2);
  else
    return nil;
  end
end

local norm = function(v1)
  local s = 0;
  for i = 1, #v1 do
    s = s + v1[i] * v1[i];
  end
  return math.sqrt(s);
end

local tostring = function(v1, formatstr)
  formatstr = formatstr or "%g";
  local str = "{"..string.format(formatstr, v1[1]);
  for i = 2, #v1 do
    str = str..", "..string.format(formatstr,v1[i]);
  end
  str = str.."}";
  return str;
end

mt.__add = add;
mt.__sub = sub;
mt.__mul = mul;
mt.__div = div;
mt.__unm = unm;
mt.__tostring = tostring;

return {
  new = new,
  ones = ones,
  zeros = zeros,
  slice = slice,
  norm = norm,
};
