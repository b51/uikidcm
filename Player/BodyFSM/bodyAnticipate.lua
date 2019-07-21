local _NAME = "bodyAnticipate";

local Body = require('Body')
local wcm = require('wcm')
local vector = require('vector')
local Config = require('Config')
local HeadFSM = require('HeadFSM')
local Motion = require('Motion');
local kick = require('kick');

local walk = require('walk');
local dive = require('dive')

local t0 = 0;
local tStart = 0;

local started = false;
local kickable = true;
local follow = false;

local goalie_dive = Config.goalie_dive or 0;
local goalie_type = Config.fsm.goalie_type;

local tStartDelay = Config.fsm.bodyAnticipate.tStartDelay;
local rCloseDive = Config.fsm.bodyAnticipate.rCloseDive;
local rMinDive = Config.fsm.bodyAnticipate.rMinDive;
local ball_velocity_thx = Config.fsm.bodyAnticipate.ball_velocity_thx;
local ball_velocity_th = Config.fsm.bodyAnticipate.ball_velocity_th;
local center_dive_threshold_y = Config.fsm.bodyAnticipate.center_dive_threshold_y;
local dive_threshold_y = Config.fsm.bodyAnticipate.dive_threshold_y;

local ball_velocity_th2 = Config.fsm.bodyAnticipate.ball_velocity_th2;
local rClose = Config.fsm.bodyAnticipate.rClose;
local rCloseX = Config.fsm.bodyAnticipate.rCloseX;

local timeout = Config.fsm.bodyAnticipate.timeout;
local thFar = Config.fsm.bodyAnticipate.thFar or {0.4,0.4,15*math.pi/180};

-- TODO(b51): Lots duplicate codes

local entry = function()
  print("BodyFSM: ".._NAME.." entry");
  t0 = Body.get_time();
  started = false;
  follow = false;
  walk.stop();
  if goalie_type>2 then
    Motion.event("diveready");
  end
end

local update = function()
  local role = gcm.get_team_role();
  if role~=0 then
    return "player";
  end

  if goalie_type>1 then
    walk.stop();
  else
    return 'position';
  end

  local t = Body.get_time();
  local ball = wcm.get_ball();

  local ball_v_inf = wcm.get_ball_v_inf();
  ball.x=ball_v_inf[1];
  ball.y=ball_v_inf[2];

  local pose = wcm.get_pose();
  local tBall = Body.get_time() - ball.t;
  local ballGlobal = util.pose_global({ball.x, ball.y, 0}, {pose.x, pose.y, pose.a});
  local ballR = math.sqrt(ball.x^2+ ball.y^2);

  -- See where our home position is...

  local homePose;
  if goalie_type<3 then
    --moving goalie
    homePose=position.getGoalieHomePose();
  else
    --diving goalie
    homePose=position.getGoalieHomePose2();
  end

  local homeRelative = util.pose_relative(homePose, {pose.x, pose.y, pose.a});
  local rHomeRelative = math.sqrt(homeRelative[1]^2 + homeRelative[2]^2);

  local goal_defend=wcm.get_goal_defend();
  local ballxy=vector.new( {ball.x,ball.y,0} );
  local aBall = math.atan2 (ball.y,ball.x);
  local posexya=vector.new( {pose.x, pose.y, pose.a} );
  ballGlobal=util.pose_global(ballxy,posexya);
  local ballR_defend = math.sqrt(
	    (ballGlobal[1]-goal_defend[1])^2+
	    (ballGlobal[2]-goal_defend[2])^2);
  local ballX_defend = math.abs(ballGlobal[1]-goal_defend[1]);

  --TODO: Diving handling

  local ball_v = math.sqrt(ball.vx^2+ball.vy^2);

  if goalie_dive > 0 and goalie_type>2 then
    if t-t0>tStartDelay and t-ball.t<0.1 then

      ballR=math.sqrt(ball.x^2+ball.y^2);

      if ball_v>ball_velocity_th and
          ball.vx<ball_velocity_thx then
        print(string.format("Ball: %.1f %.1f Velocity: %.2f %.2f aBall: %.1f",
            ball.x,ball.y,ball.vx,ball.vy,aBall));
      end

      if ball.vx<ball_velocity_thx and
          ballR<rCloseDive and
          ballR>rMinDive and
          ball_v>ball_velocity_th then
        t0=t;
        local py = ball.y - (ball.vy/ball.vx) * ball.x;
        print("Ball velocity:",ball.vx,ball.vy);
        print("Projected y pos:",py);
        if math.abs(py)<dive_threshold_y then
          if py>center_dive_threshold_y then
            dive.set_dive("diveLeft");
          elseif py<-center_dive_threshold_y then
            dive.set_dive("diveRight");
          else
            dive.set_dive("diveCenter");
          end
          Motion.event("dive");
          return "dive";
        end
      end
    end
  end

  aBall = math.atan2 (ball.y,ball.x);

  --Penalty mark: 1.2m
  --Penalty box: 0.6m
  local rCloseX2 = 0.8; --absolute min X pos
  local eta_kickaway = 3.0;
  local attacker_eta = wcm.get_team_attacker_eta();

  -- if goalie_dive~=1 or goalie_type<3 then
  if true then --Always reposition
    if t-ball.t<0.1 and ball_v < ball_velocity_th2 then
      --ball is not moving, check whether we go out for kicking
      if ballX_defend<rCloseX2 or
      -- ((ballX_defend<rCloseX or ballR_defend<rClose)
          (ballR_defend<rClose and
          attacker_eta > eta_kickaway) then
        Motion.event("walk");
        return "ballClose";
      end
    end
    if Config.fsm.goalie_reposition==1 then --check yaw error only
      if (t - t0 > timeout) and
        math.abs(aBall) > thFar[3] then
        Motion.event("walk");
        return 'position';
      end
    --check yaw and position error
    elseif Config.fsm.goalie_reposition==2 then
      if (t - t0 > timeout) and
	        (rHomeRelative>math.sqrt(thFar[1]^2+thFar[2]^2) or
          math.abs(aBall) > thFar[3]) then
        Motion.event("walk");
        return 'position';
      end
    end
  end
end

local exit = function()
  walk.start();
end

return {
  _NAME = _NAME,
  entry = entry,
  update = update,
  exit = exit,
};
