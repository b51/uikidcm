--DARWIN OP specific keyframe playing file
local Body = require('Body')
local vector = require('vector')
local walk = require('walk')

--Upperbody only keyframe?
local is_upper=false;

--Loaded motion data
local motData = {};

--Queued motions
local motQueue = {};

--Added for debugging
local joints = {};

local iFrame = 0;
local tFrameStart = 0;
local nServo = 0;
local t0 = Body.get_time();
local started = false;

local load_motion_file = function(fname, key)
  -- load the given keyframe motion
  key = key or fname;
  local mot = dofile(fname);
  motData[key] = mot;
--  print_motion_file(fname,mot)
end

--[[
function print_motion_file(fname,mot)
  print(fname)
  for i=1,#mot.keyframes do
    print("{\nangles=vector.new({")
    local ang=vector.new(mot.keyframes[i].angles);
    print(string.format(
	"%d,%d,\n%d,%d,%d,\n%d,%d,%d,%d,%d,%d,\n%d,%d,%d,%d,%d,%d,\n%d,%d,%d",
      table.unpack(ang*180/math.pi) ));
    print"})*math.pi/180,"
    print(string.format("duration = %.1f;\n},",mot.keyframes[i].duration));
  end
end
--]]

local do_motion = function(key)
  -- add the keyframe motion to the queue
  if (motData[key]) then
    table.insert(motQueue, motData[key]);
  end
end

local get_queue_len = function()
  return #motQueue;
end

local entry = function()
  motQueue = {};
  iFrame = 0;

  --OP specific : Wait for a bit to read current joint angles
  Body.set_syncread_enable(1);
  t0=Body.get_time();
  started=false;

  --Remove actuator velocity limits
  for i = 1,Body.nJoint do
    Body.set_actuator_velocity(0, i);
  end
end

local reset_tFrameStart = function()
  tFrameStart = Body.get_time();
end

local update = function()
  local specialValid = Body.get_state_specialValid()--123456≈–î‡ «∑Òœ»Ï∂ΩY ¯
  local isComplete = Body.get_state_specialGaitPending();
  if (#motQueue == 0 or (specialValid[1] == 0 and isComplete[1] == 0)) then
    motQueue = {};--123456≈–î‡ «∑Òœ»Ï∂ΩY ¯
    return "done";
  end

  local mot = motQueue[1];
  local t = Body.get_time();
  if not started then
    if t-t0<0.1 then
        return iFrame;
    end--wait 0.1sec to read joint positions
    started=true;
  end
  if (iFrame == 0) then
    -- starting a new keyframe motion
    iFrame = 1;
    nServo = #(mot.servos);
    tFrameStart = t;
    -- get current joint positions
    local q1 = vector.new({});
    for i = 1,nServo do
      q1[i] = Body.get_sensor_position(mot.servos[i]);
    end
    --Added for debugging
    joints = q1;
    Body.set_syncread_enable(0);
  end

  -- linear interpolation of joint position based on the specified duration
  local duration = mot.keyframes[iFrame].duration;
  local h = (t-tFrameStart)/duration;
  h = math.min(h, 1);

  local q = q1 + h*(mot.keyframes[iFrame].angles - q1);

  if is_upper then --upper body only motion
    print('upper');
    for i=1,5 do
      Body.set_actuator_command(q[i], mot.servos[i]);
    end
    for i=18,20 do
      Body.set_actuator_command(q[i], mot.servos[i]);
    end
  else
    -- set joint stiffnesses if specified
    local stiffnesses = mot.keyframes[iFrame].stiffness;
    if (stiffnesses and (#stiffnesses == nServo)) then
      for i = 1,nServo do
        Body.set_actuator_hardness(stiffnesses[i], mot.servos[i]);
      end
    end
    for i = 1,nServo do
      Body.set_actuator_command(q[i], mot.servos[i]);
    end
  end

  if (h >= 1) then
    -- finished current frame
    q1 = vector.new(mot.keyframes[iFrame].angles);
    tFrameStart = t;
    iFrame = iFrame + 1;
    if (iFrame > #(mot.keyframes)) then
      table.remove(motQueue, 1);
      iFrame = 0;
    end
  end
  return iFrame;
end

local getJoints = function()
  return joints;
  --print vector positions for debugging--
  --	local str = vector.tostring(joints);
  --	return str;
end

local exit = function()
  -- disable joint encoder reading
  -- WHYY?
  Body.set_syncread_enable(0);
end

return {
  entry = entry,
  update = update,
  exit = exit,
  load_motion_file = load_motion_file,
  do_motion = do_motion,
  get_queue_len = get_queue_len,
  reset_tFrameStart = reset_tFrameStart,
  getJoints = getJoints,
}
