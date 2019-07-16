local vector = require('vector');

local mt = {};
-- TODO(b51): use cartographer rigid_transform to replace this

local inv = function(a)
  local t = {};
  local r = {};
  local p = {};
  r[1] = vector.new({a[1][1],a[2][1],a[3][1]});
  r[2] = vector.new({a[1][2],a[2][2],a[3][2]});
  r[3] = vector.new({a[1][3],a[2][3],a[3][3]});
  p = vector.new({a[1][4],a[2][4],a[3][4]});
  t[1] = vector.new({r[1][1],r[1][2],r[1][3],-(r[1][1]*p[1]+r[1][2]*p[2]+r[1][3]*p[3])});
  t[2] = vector.new({r[2][1],r[2][2],r[2][3],-(r[2][1]*p[1]+r[2][2]*p[2]+r[2][3]*p[3])});
  t[3] = vector.new({r[3][1],r[3][2],r[3][3],-(r[3][1]*p[1]+r[3][2]*p[2]+r[3][3]*p[3])});
  t[4] = vector.new({0,0,0,1});
  return setmetatable(t,mt);
end

local eye = function()
  local t = {};
  t[1] = vector.new({1, 0, 0, 0});
  t[2] = vector.new({0, 1, 0, 0});
  t[3] = vector.new({0, 0, 1, 0});
  t[4] = vector.new({0, 0, 0, 1});
  return setmetatable(t, mt);
end

local rotZ = function(a)
  local ca = math.cos(a);
  local sa = math.sin(a);
  local t = {};
  t[1] = vector.new({ca, -sa, 0, 0});
  t[2] = vector.new({sa, ca, 0, 0});
  t[3] = vector.new({0, 0, 1, 0});
  t[4] = vector.new({0, 0, 0, 1});
  return setmetatable(t, mt);
end

local rotY = function(a)
  local ca = math.cos(a);
  local sa = math.sin(a);
  local t = {};
  t[1] = vector.new({ca, 0, sa, 0});
  t[2] = vector.new({0, 1, 0, 0});
  t[3] = vector.new({-sa, 0, ca, 0});
  t[4] = vector.new({0, 0, 0, 1});
  return setmetatable(t, mt);
end

local rotX = function(a)
  local ca = math.cos(a);
  local sa = math.sin(a);
  local t = {};
  t[1] = vector.new({1, 0, 0, 0});
  t[2] = vector.new({0, ca, -sa, 0});
  t[3] = vector.new({0, sa, ca, 0});
  t[4] = vector.new({0, 0, 0, 1});
  return setmetatable(t, mt);
end

local trans = function(dx, dy, dz)
  local t = {};
  t[1] = vector.new({1, 0, 0, dx});
  t[2] = vector.new({0, 1, 0, dy});
  t[3] = vector.new({0, 0, 1, dz});
  t[4] = vector.new({0, 0, 0, 1});
  return setmetatable(t, mt);
end

mt.__mul = function(t1, t2)
  local t = {};
  if (type(t2[1]) == "number") then
    for i = 1,4 do
      t[i] = t1[i][1] * t2[1]
              + t1[i][2] * t2[2]
              + t1[i][3] * t2[3]
              + t1[i][4] * t2[4];
    end
    return vector.new(t);
  elseif (type(t2[1] == "table")) then
    for i = 1,4 do
      t[i] = {};
      for j = 1,4 do
        t[i][j] = t1[i][1] * t2[1][j]
                  + t1[i][2] * t2[2][j]
                  + t1[i][3] * t2[3][j]
                  + t1[i][4] * t2[4][j];
      end
    end
    return setmetatable(t, mt);
  end
end

local getRYP = function(t)
  -- http://planning.cs.uiuc.edu/node103.html
  -- returns [roll, pitch, yaw] vector
  local e=vector.zeros(3);
  e[1]=math.atan2(t[3][2],t[3][3]); --Roll
  e[2]=math.atan2(-t[3][1],math.sqrt( t[3][2]^2 + t[3][3]^2) ); -- Pitch
  e[3]=math.atan2(t[2][1],t[1][1]); -- Yaw
  return e;
end

return{
  inv = inv,
  eye = eye,
  rotX = rotX,
  rotY = rotY,
  rotZ = rotZ,
  trans = trans,
  getRYP = getRYP,
};
