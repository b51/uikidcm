local vector = require('vector');
local unix = require('unix');
-----------------------------------------------------------------
--                        Config:
--              {platform, dev, game, km}
-----------------------------------------------------------------
local Config = {};
Config.platform = {};
Config.dev = {};
Config.game = {};
Config.km = {};

-----------------------------------------------------------------
--          append Config from submodule configs
--
--  Config_Robot    : {stance, head, gyro, acc, angle, servo}
--  Config_Walk     : {walk}
--  Config_Kick     : {kick}
--  Config_FSM      : {fsm}
--  Config_Yolo_Net : {net}
--  Config_Vision   : {color, vision} TODO(b51): color is useless now
--  Config_Camera   : {camera}
--  Config_World    : {world, occ}
-----------------------------------------------------------------
local loadconfig = function(configName)
  local localConfig = require(configName);
  for k, v in pairs(localConfig) do
    Config[k]=localConfig[k];
  end
end

loadconfig('Robot/Config_Robot')
loadconfig('Walk/Config_Walk')
loadconfig('Kick/Config_Kick')
loadconfig('FSM/Config_FSM')
loadconfig('Net/Config_Yolo_Net')
loadconfig('Vision/Config_Vision')
loadconfig('Vision/Config_Camera')
loadconfig('World/Config_World')

local platform = Config.platform;
platform.name = 'MOS';

--Robot CFG should be loaded first to set PID values
local robotName=unix.gethostname();

-- Device Interface Libraries
local dev = Config.dev;
dev.body = 'MOSBody';
dev.camera = 'V4LCam';
dev.kinematics = 'OPKinematics';
dev.ip_wired = '192.168.2.200';
--dev.ip_wireless = '255.255.255.255';
dev.ip_wireless = '192.168.1.255';  --Our Router
dev.ip_wireless_port = 54321;
dev.game_control = 'GameControl';
dev.team = 'TeamBasic';
dev.walk = 'BasicWalk';
dev.kick = 'BasicKick'

-- Game Parameters
local game = Config.game;
game.teamNumber = 6;
--Default role: 0 for goalie, 1 for attacker, 2 for defender
game.role = 1;
--Default team: 0 for blue, 1 for red
game.teamColor = 0; --Blue team, attacking Yellow goal
--game.teamColor = 1; --Red team, attacking Cyan goal
game.robotName = robotName;
game.playerID = 3;
game.robotID = game.playerID;
game.nPlayers = 5;
--------------------

--FSM and behavior settings
--SJ: loading FSM config  kills the variable fsm, so should be called first
--??? what "kills the variable fsm" meaning

-- Team Parameters
local team = {};
team.msgTimeout = 5.0;
team.tKickOffWear = 7.0;

team.walkSpeed = 0.25; --Average walking speed
team.turnSpeed = 1.0; --Average turning time for 360 deg
team.ballLostPenalty = 4.0; --ETA penalty per ball loss time
team.fallDownPenalty = 4.0; --ETA penalty per ball loss time
team.nonAttackerPenalty = 0.8; -- distance penalty from ball
team.nonDefenderPenalty = 0.5; -- distance penalty from goal

team.force_defender = 0;--Enable this to force defender mode

--if ball is away than this from our goal, go support
team.support_dist = 3.0;
team.supportPenalty = 0.5; --dist from goal

--Team ball parameters
team.use_team_ball = 1;
team.team_ball_timeout = 3.0;  --use team ball info after this delay
team.team_ball_threshold = 0.5; --Min score to use team ball

team.avoid_own_team = 1;
team.avoid_other_team = 0;

-- keyframe files
local km = Config.km;
km.standup_front = 'km_NSLOP_StandupFromFront.lua';
km.standup_back = 'km_NSLOP_StandupFromBack.lua';

--goalie_dive = 1; --1 for arm only, 2 for actual diving
Config.goalie_dive = 2;
Config.goalie_dive_waittime = 3.0; --How long does goalie lie down?
Config.listen_monitor = 1;
--Fall check
Config.fallAngle = 50*math.pi/180;
Config.falling_timeout = 5.0;
Config.ball_shift={0,0};

return Config;
