local _NAME = "headTrackGoalie"

local Body = require('Body')
local HeadTransform = require('HeadTransform')
local Config = require('Config')
local wcm = require('wcm')

local t0_ = 0;
local minDist_ = Config.fsm.headTrack.minDist;
local fixTh_ = Config.fsm.headTrack.fixTh;
local trackZ_ = Config.vision.ball_diameter;
local timeout_ = Config.fsm.headTrack.timeout;
local tLost_ = Config.fsm.headTrack.tLost;

local th_lock_ = 5*math.pi/180;
local th_unlock_ = 15*math.pi/180;

local goalie_dive_ = Config.goalie_dive or 0;
local goalie_type_ = Config.fsm.goalie_type;
local locked_on_ = false;

local entry = function()
  print("HeadFSM:".._NAME.." entry");
  t0_ = Body.get_time();
  locked_on_ = false;
  wcm.set_ball_locked_on(0);
end

local update = function()
  if goalie_type_ < 3 then --Non-diving goalie, escape to headTrack
    return "player"
  end

  local t = Body.get_time();

  -- update head position based on ball location
  local ball = wcm.get_ball();
  local ballR = math.sqrt (ball.x^2 + ball.y^2);

  local yawTarget, pitchTarget = HeadTransform.ikineCam(ball.x,
                                                        ball.y,
                                                        trackZ,
                                                        bottom);
--  local headAngles = Body.get_sensor_headpos();--123456
  local headAngles = {Body.get_sensor_headpos()[2],
                      Body.get_sensor_headpos()[1]};	--b51

  pitchOffset = 10*math.pi/180;
  pitchTarget = pitchTarget + pitchOffset;

  local yaw_error = yawTarget - headAngles[1];
  local pitch_error = pitchTarget - headAngles[2];
  local angle_error = math.sqrt(yaw_error^2+pitch_error^2);

  if not locked_on_ then
    Body.set_head_command({yawTarget, pitchTarget});
    Body.set_para_headpos(vector.new({yawTarget, pitchTarget}));--123456î^²¿
    Body.set_state_headValid(1);--123456î^²¿
  end

  if locked_on_ then
    if angle_error > th_unlock_ then
      locked_on_ = false;
      wcm.set_ball_locked_on(0);
    end
  else
    if angle_error < th_lock_ then
      locked_on_ = true;
      wcm.set_ball_locked_on(1);
    end
  end

  if (t - ball.t > tLost_) then
    print('Ball lost!');
    return "lost";
  end

end

local exit = function()
  wcm.set_ball_locked_on(0);
end

return {
  _NAME = _NAME,
  entry = entry,
  update = update,
  exit = exit,
};
