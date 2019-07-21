local Config = require('Config');
local Transform = require('Transform');
local vector = require('vector');
local vcm = require('vcm');
local mcm = require('mcm');

-- TODO(b51): horizonA, horizonB, labelA, labelB, focalA is deprecated,
--            should use origin image size to do transform
-- TODO(b51): Draw transform details of every function

local tHead_ = Transform.eye();
local tNeck_ = Transform.eye();
local camPosition_ = 0;

local camOffsetZ_ = Config.head.camOffsetZ;
local pitchMin_ = Config.head.pitchMin;
local pitchMax_ = Config.head.pitchMax;
local yawMin_ = Config.head.yawMin;
local yawMax_ = Config.head.yawMax;

local cameraPos_ = Config.head.cameraPos;
local cameraAngle_ = Config.head.cameraAngle;

local horizonA_ = 1;
local horizonB_ = 1;
local horizonDir_ = 0;

local labelA_ = {};
labelA_.m = Config.camera.width/2;
labelA_.n = Config.camera.height/2;

local u0_ = Config.camera.x_center;
local v0_ = Config.camera.y_center;
local focalU_ = Config.camera.focal_length;
local focalV_ = Config.camera.focal_base;

local nxA_ = labelA_.m;
local x0A_ = 0.5 * (nxA_-1);
local nyA_ = labelA_.n;
local y0A_ = 0.5 * (nyA_-1);
local focalA_ = Config.camera.focal_length/(Config.camera.focal_base/nxA_);

local scaleB_ = Config.vision.scaleB;
local labelB_ = {};
labelB_.m = labelA_.m/scaleB_;
labelB_.n = labelA_.n/scaleB_;
local nxB_ = nxA_/scaleB_;
local x0B_ = 0.5 * (nxB_-1);
local nyB_ = nyA_/scaleB_;
local y0B_ = 0.5 * (nyB_-1);
local focalB_ = focalA_/scaleB_;

local neckX_ = Config.head.neckX;
local neckZ_ = Config.head.neckZ;
local footX_ = Config.walk.footX;

local rayIntersectA = function(c)
  local p0 = vector.new({0,0,0,1.0});
  local p1 = vector.new({focalA_,-(c[1]-x0A_),-(c[2]-y0A_),1.0});

  p1 = tHead_ * p1;
  local p0 = tNeck_ * p0;
  local v = p1 - p0;
  local t = -p0[3]/v[3];
  -- if t < 0, the x value will be projected behind robot, simply reverse it
  -- since it is always very far away
  if (t < 0) then
    t = -t;
  end
  local t = -p0[3]/v[3];
   -- if t < 0, the x value will be projected behind robot, simply reverse it
  -- since it is always very far away
  if (t < 0) then
    t = -t;
  end
  local p = p0 + t * v;
  local uBodyOffset = mcm.get_walk_bodyOffset();
  p[1] = p[1] + uBodyOffset[1];
  p[2] = p[2] + uBodyOffset[2];
  return p;
end

local rayIntersectB = function(c)
  local p0 = vector.new({0,0,0,1.0});
  local p1 = vector.new({focalB_,-(c[1]-x0B_),-(c[2]-y0B_),1.0});

  p1 = tHead_ * p1;
  local p0 = tNeck_ * p0;
  local v = p1 - p0;
  local t = -p0[3]/v[3];
  -- if t < 0, the x value will be projected behind robot, simply reverse it
  -- since it is always very far away
  if (t < 0) then
    t = -t;
  end
  local p = p0 + t * v;
  local uBodyOffset = mcm.get_walk_bodyOffset();
  p[1] = p[1] + uBodyOffset[1];
  p[2] = p[2] + uBodyOffset[2];
  return p;
end

local get_horizonA = function()
  return horizonA_;
end

local get_horizonB = function()
  return horizonB_;
end

local get_horizonDir = function()
  return horizonDir_;
end

local coordinatesA = function(c, scale)
  --[[
  scale = scale or 1;
  local v = vector.new({focalA_,
                       -(c[1] - x0A_),
                       -(c[2] - y0A_),
                       scale});
  --]]
  local _scale = scale or 1;
  local v = vector.new({focalU_,
                       -(c[1] - u0_),
                       -(c[2] - v0_),
                       _scale});
  v = tHead_*v;
  v = v/v[4];
  return v;
end

local coordinatesB = function(c, scale)
  local _scale = scale or 1;
  local v = vector.new({focalB_,
                        -(c[1] - x0B_),
                        -(c[2] - y0B_),
                        _scale});
  v = tHead_*v;
  v = v/v[4];
  return v;
end

local getNeckOffset = function()
  local bodyHeight=vcm.get_camera_bodyHeight();
  local bodyTilt=vcm.get_camera_bodyTilt();

  --SJ: calculate tNeck here
  --So that we can use this w/o run update
  --(for test_vision)
  local tNeck0 = Transform.trans(-footX_,0,bodyHeight);
  tNeck0 = tNeck0*Transform.rotY(bodyTilt);
  tNeck0 = tNeck0*Transform.trans(neckX_,0,neckZ_);
  local v=vector.new({0,0,0,1});
  v=tNeck0*v;
  v=v/v[4];
  return v;
end

local getCameraRoll = function()
  --Use camera IK to calculate how much the image is tilted
  --headAngles = Body.get_head_position();
  local headAngles = {Body.get_sensor_headpos()[2],Body.get_sensor_headpos()[1]};	--b51
  local r = 3.0;
  local z0 = 0;
  local z1 = 0.7;
  local x0=r*math.cos(headAngles[1]);
  local y0=r*math.sin(headAngles[1]);
  local yaw1, pitch1=ikineCam0(x0,y0,z0,bottom);
  local yaw2, pitch2=ikineCam0(x0,y0,z1,bottom);
  local tiltAngle = math.atan((yaw2-yaw1)/(pitch1-pitch2));
  return tiltAngle;
end

--Camera IK without headangle limit
local ikineCam0 = function(x,y,z,select)
  local bodyHeight = vcm.get_camera_bodyHeight();
  local bodyTilt = vcm.get_camera_bodyTilt();
  local pitch0 = mcm.get_headPitchBias();

  --Bottom camera by default (cameras are 0 indexed so add 1)
  local _select = (select or 0) + 1;

  --Look at ground by default
  local _z = z or 0;

  --Cancel out the neck X and Z offset
  local v = getNeckOffset();
  x = x-v[1];
  _z = _z-v[3];

  --Cancel out body tilt angle
  v = Transform.rotY(-bodyTilt)*vector.new({x,y,_z,1});
  v=v/v[4];

  x,y,_z=v[1],v[2],v[3];
  local yaw = math.atan2(y, x);

  local norm = math.sqrt(x^2 + y^2 + _z^2);
--  local pitch = math.asin(-z/(norm + 1E-10));

  --new IKcam that takes camera offset into account
  -------------------------------------------------------------
  -- sin(pitch)x + cos (pitch) z = c , c=camera z offset
  -- pitch = atan2(x,z) - acos(b/r),  r= sqrt(x^2+z^2)
  -- r*sin(pitch) = z *cos(pitch) + c,
  -------------------------------------------------------------
  local c=cameraPos_[_select][3];
  local r = math.sqrt(x^2+y^2);
  local d = math.sqrt(r^2+_z^2);
  local p0 = math.atan2(r,_z) - math.acos(c/(d + 1E-10));

  local pitch=p0;
  pitch = pitch - cameraAngle_[_select][2]- pitch0;
  return yaw, pitch;
end

local ikineCam = function(x, y, z, select)
  local yaw,pitch=ikineCam0(x,y,z,select);
  yaw = math.min(math.max(yaw, yawMin_), yawMax_);
  pitch = math.min(math.max(pitch, pitchMin_), pitchMax_);
  return yaw,pitch;
end

--Project 3d point to level plane with some height
local projectGround = function(v,targetheight)
  targetheight=targetheight or 0;
  local cameraOffset=getCameraOffset();
  local vout=vector.new(v);

  --Project to plane
  if v[3]<targetheight then
    vout = cameraOffset + (v-cameraOffset) *
        ((cameraOffset[3]-targetheight) / (cameraOffset[3] - v[3]));
  end

  --Discount body offset
  --uBodyOffset = mcm.get_walk_bodyOffset();
  vout[1] = vout[1];-- + uBodyOffset[1];
  vout[2] = vout[2];-- + uBodyOffset[2];
  return vout;
end

local getCameraOffset = function()
  local v=vector.new({0,0,0,1});
  v=tHead_*v;
  v=v/v[4];
  return v;
end

local entry = function()
end

-- TODO(b51): bodyHeight, bodyTilt can make as local variable outside function
--function update(sel,headAngles,compY)
local update = function(sel,headAngles)
  -- Now bodyHeight, Tilt, camera pitch angle bias are read from vcm
  -- compY = compY or 0;
  local bodyHeight = vcm.get_camera_bodyHeight();
  local bodyTilt = vcm.get_camera_bodyTilt();
  local pitch0 = mcm.get_headPitchBias();
--[[
  vcm.add_debug_message(string.format(
  "HeadTrasnform update:\n bodyHeight %.2f bodyTilt %d pitch0 %d headangle %d %d\n",
	 bodyHeight, bodyTilt*180/math.pi, pitch0*180/math.pi,
	 headAngles[1]*180/math.pi,
	(headAngles[2]+pitch0)*180/math.pi));
]]--

  -- cameras are 0 indexed so add one for use here
  sel = sel + 1;
  tNeck_ = Transform.trans(-footX_,0,bodyHeight);
--  tNeck_ = Transform.trans(-footX_,compY,bodyHeight);	--b51:for compensate robot Y
  tNeck_ = tNeck_*Transform.rotY(bodyTilt);
  tNeck_ = tNeck_*Transform.trans(neckX_,0,neckZ_);
  --pitch0 is Robot specific head angle bias (for OP)
  tNeck_ = tNeck_*Transform.rotZ(headAngles[1])*Transform.rotY(headAngles[2]+pitch0);
	--print("headAngles[1], headAngles[2], pitch0 :"..headAngles[1], headAngles[2], pitch0);
    --print("cameraPos_[sel][1], cameraPos_[sel][2], cameraPos_[sel][3] :"..cameraPos_[sel][1], cameraPos_[sel][2], cameraPos_[sel][3]);
  tHead_ = tNeck_*Transform.trans(cameraPos_[sel][1], cameraPos_[sel][2], cameraPos_[sel][3]);
  tHead_ = tHead_*Transform.rotY(cameraAngle_[sel][2]);

  --update camera position
  local vHead=vector.new({0,0,0,1});
  vHead = tHead_*vHead;
  vHead = vHead/vHead[4];
  vcm.set_camera_height(vHead[3]);

  -- update horizon
  local pa = headAngles[2] + cameraAngle_[sel][2]; --+ bodyTilt;
  horizonA_ = (labelA_.n/2.0) - focalA_*math.tan(pa) - 2;
  horizonA_ = math.min(labelA_.n, math.max(math.floor(horizonA_), 0));
  horizonB_ = (labelB_.n/2.0) - focalB_*math.tan(pa) - 1;
  horizonB_ = math.min(labelB_.n, math.max(math.floor(horizonB_), 0));
  --print('horizon-- pitch: '..pa..'  A: '..horizonA_..'  B: '..horizonB_);
  -- horizon direction
  local ref = vector.new({0,1,0,1});
  local p0 = vector.new({0,0,0,1});
  local ref1 = vector.new({0,-1,0,1});
  p0 = tHead_*p0;
  ref = tHead_*ref;
  ref1 = tHead_*ref1;
  ref = ref - p0;
  ref1 = ref1 - p0;
  -- print(ref,' ',ref1);
  local v = {};
  v[1] = -math.abs(ref1[1]) * focalA_ / 4 + x0A_;
  v[2] = ref1[3] * focalA_ / 4 + y0A_;
  v[3] = math.abs(ref[1]) * focalA_ / 4 + x0A_;
  v[4] = ref[3] * focalA_ / 4 + y0A_;
  horizonDir_ = math.atan2(ref1[3],math.sqrt(ref1[1]^2+ref1[2]^2));
end

local exit = function()
end

return {
  entry = entry,
  update = update,
  exit = exit,
  rayIntersectA = rayIntersectA,
  rayIntersectB = rayIntersectB,
  get_horizonA = get_horizonA,
  get_horizonB = get_horizonB,
  get_horizonDir = get_horizonDir,
  coordinatesA = coordinatesA,
  coordinatesB = coordinatesB,
  getNeckOffset = getNeckOffset,
  getCameraRoll = getCameraRoll,
  ikineCam0 = ikineCam0,
  ikineCam = ikineCam,
  projectGround = projectGround,
  getCameraOffset = getCameraOffset,
};
