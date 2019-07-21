local Body = require('Body')
local Config = require('Config')
local wcm = require('wcm')
local gcm = require('gcm')
local vector = require('vector')
local walk = require('walk')
local position = require('position')

local demo_behavior = 0;
local kickDir = 1;
local kickType = 1;

-- TODO(b51): kick dir should fix with out color

local cycle_behavior = function()
  demo_behavior = demo_behavior%4 + 1;

  if demo_behavior == 1 then
    print("Front kick test");
    kickDir=1;
    kickType=1;
  elseif demo_behavior == 2 then
    print("Side kick test");
    kickDir=2;
    kickType=1;
  elseif demo_behavior == 3 then
    print("Front walkkick test");
    kickDir=1;
    kickType=2;
  elseif demo_behavior == 4 then
    print("Side walkkick test");
    kickDir=2;
    kickType=2;
  end
end

--Initial kick for demo
if Config.fsm.playMode==1 then
  demo_behavior = 0;
  cycle_behavior();
end

local update = function()
  -----------------------------------------------------------
  --Kick dir:1 front, 2 to the left, 3 to the right
  --Kick type: 1 stationary kick, 2 walkkick, (3 dribble)

  -------------------------------
  --Kickoff handling
  ------------------------------
  local tKickOffWear = Config.team.tKickOffWear or 30.0;

  local t=Body.get_time();
  local kick_off=wcm.get_kick_kickOff();
  local tKickOff=wcm.get_kick_tKickOff();
  --If too long time has passed since game starts
  --Don't care about kickoff kick
  if (t-tKickOff)>tKickOffWear and kick_off==1 then
    print("kickoff weared off")
    wcm.set_kick_kickOff(0);
    kick_off=0;
  end

  local kickAngle = 0;
  if Config.fsm.playMode>1 then --skip kick selection in demo mode
    if kick_off>0 then
      kickAngle = math.pi/6; --30 degree off angle
      kickDir=1;
      kickType=2;
      wcm.set_kick_dir(kickDir);
      wcm.set_kick_type(kickType);
      wcm.set_kick_angle(kickAngle);
      return;
    end

    position.posCalc();
    local aGoal = wcm.get_goal_attack_angle2();
    local pose = wcm.get_pose();

    local angleRot = util.mod_angle(aGoal - pose.a);

    --Check if front walkkick is available now
    kickType=2;

    --Check kick direction
    local thSideKick1 = Config.fsm.thSideKick1 or 45*math.pi/180;
    local thSideKick2 = Config.fsm.thSideKick2 or 135*math.pi/180;
    local thDistSideKick = Config.fsm.thDistSideKick or 3.0;

    local ball = wcm.get_ball();
    local rBall = math.sqrt(ball.x^2+ball.y^2);

    if rBall > thDistSideKick or
        math.abs(angleRot)<thSideKick1 or
        math.abs(angleRot)>thSideKick2	then
      --print("STRAIGHT",angleRot*180/math.pi)
      kickDir=1;
      kickAngle = 0;
    elseif angleRot>0 then --should kick to the left
      --print("LEFT",angleRot*180/math.pi)
      kickDir=2;
      kickAngle = 70*math.pi/180;
    else
      --print("RIGHT",angleRot*180/math.pi)
      kickDir=3;
      kickAngle = -70*math.pi/180;
    end
  else --Demo mode
    if kickDir>1 then
      kickDir=5-kickDir; --Switch sidekick direction for demo mode
    end
    kickAngle = 0;
  end

  if walk.canWalkKick ~= 1 or Config.fsm.enable_walkkick == 0 then
    kickType=1;  --stationary kick
  end

  if Config.fsm.enable_sidekick==0 and kickDir~=1 then
    kickDir=1;
    kickAngle=0;
  end

  wcm.set_kick_dir(kickDir);
  wcm.set_kick_type(kickType);
  wcm.set_kick_angle(kickAngle);
end

local get_attack_bearing_pose = function(pose0)
  local postYellow = Config.world.postYellow;
  local postCyan = Config.world.postCyan;

  local postAttack;
  if gcm.get_team_color() == 1 then
    -- red attacks cyan goal
    postAttack = postCyan;
  else
    -- blue attack yellow goal
    postAttack = postYellow;
  end

  -- make sure not to shoot back towards defensive goal:
  local xPose = math.min(math.max(pose0.x, -0.99*PoseFilter.xLineBoundary),
                          0.99*PoseFilter.xLineBoundary);
  local yPose = pose0.y;
  local aPost = {}
  aPost[1] = math.atan2(postAttack[1][2]-yPose, postAttack[1][1]-xPose);
  aPost[2] = math.atan2(postAttack[2][2]-yPose, postAttack[2][1]-xPose);
  local daPost = math.abs(util.mod_angle(aPost[1]-aPost[2]));

  local attackHeading = aPost[2] + .5*daPost;
  local attackBearing = PoseFilter.mod_angle(attackHeading - pose0.a);

  return attackBearing, daPost;
end

return {
  _NAME = "behavior",
  cycle_behavior = cycle_behavior,
  update = update,
  get_attack_bearing_pose = get_attack_bearing_pose,
};
