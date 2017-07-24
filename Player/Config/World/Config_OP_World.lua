module(..., package.seeall);
require('vector')

--Localization parameters 

world={};
world.n = 250;  --tse
world.xLineBoundary = 4.5;
world.yLineBoundary = 3.0;
world.xMax = 4.5;
world.yMax = 3.0;
world.goalWidth = 2.60;
world.goalHeight= 1.80;
world.ballYellow= {{5,0.0}};
world.ballCyan= {{-5,0.0}};
world.postYellow = {};
world.postYellow[1] = {4.5, 0.5};
world.postYellow[2] = {4.5, -0.5};
world.postCyan = {};
world.postCyan[1] = {-4.5, -0.5};
world.postCyan[2] = {-4.5, 0.5};
world.spot = {};
world.spot[1] = {-2.77, 0};
world.spot[2] = {2.77, 0};
world.landmarkCyan = {0.0, -2.4};
world.landmarkYellow = {0.0, 2.4};
world.cResample = 10; --Resampling interval

--SJ: Now kidsize is using SPL field 
--Kidsize values
world.Lcorner={};
--Field edge
world.Lcorner[1]={4.5,3.0};
world.Lcorner[2]={4.5,-3.0};
world.Lcorner[3]={-4.5,3.0};
world.Lcorner[4]={-4.5,-3.0};
--Center T edge
world.Lcorner[5]={0,3.0};
world.Lcorner[6]={0,-3.0};
--Penalty box edge
world.Lcorner[7]={-3.9,1.725};
world.Lcorner[8]={-3.9,-1.725};
world.Lcorner[9]={3.9,1.725};
world.Lcorner[10]={3.9,-1.725};
--Penalty box T edge
world.Lcorner[11]={4.5,1.725};
world.Lcorner[12]={4.5,-1.725};
world.Lcorner[13]={-4.5,1.725};
world.Lcorner[14]={-4.5,-1.725};
--Center circle junction
world.Lcorner[15]={0,0.75};
world.Lcorner[16]={0,-0.75};
world.Lcorner[17]={2.4,2};


--[[
--SJ: NSL penalty box is very wide 
--And sometimes they can be falsely detected as T edges
--Penalty box T edge #2 
world.Lcorner[18]={2.4,-2};
world.Lcorner[19]={-2.4,2};
world.Lcorner[20]={-2.4,-2};
--]]


--SJ: OP does not use yaw odometry data (only use gyro)
--world.odomScale = {1, 1, 0};  
--world.imuYaw = 1;
--Vision only testing (turn off yaw gyro)
world.odomScale = {1, 1, 1};  
world.imuYaw = 0;

world.imuYaw_update = 1;
world.cimuYaw_count = 1;
world.imuYaw_of_fieldXp = 162*math.pi/180;
world.imuYaw_of_fieldYp = -100*math.pi/180 + 2*math.pi;
world.imuYaw_of_fieldXm = -1*math.pi/180 + 2*math.pi;
world.imuYaw_of_fieldYm = 100*math.pi/180 + 2*math.pi;
world.aImuYawFilter = 0.05;
world.imuGoal_angleThres = 40*math.pi/180;

world.attackZero = world.imuYaw_of_fieldXp;

-- default positions for our kickoff
world.initPosition1={
  {4.3,0},   --Goalie
  {0.5,0}, --Attacker
  {2.2,-1.8}, --Defender
  {0.5,1.0}, --Supporter
}
-- default positions for opponents' kickoff
-- Center circle radius: 0.75
world.initPosition2={
  {4.3,0},   --Goalie
--Old position
--  {0.8,0}, --Attacker
--  {1.5,-0.5}, --Defender

--Now bit back

  {1.2,0}, --Attacker
  {2.0,-0.5}, --Defender

  {1.8,1.0}, --Supporter
}

-- default positions for dropball
-- Center circle radius: 0.75
world.initPosition3={
  {4.3,0},   --Goalie
  {0.5,0}, --Attacker
  {1.5,-1.5}, --Defender
  {0.5,1.0}, --Supporter
}

-- filter weights
world.rGoalFilter = 0.08;
world.aGoalFilter = 0.05;
world.rPostFilter = 0.08;
world.aPostFilter = 0.05;

world.rLandmarkFilter = 0.05;
world.aLandmarkFilter = 0.10;

--SJ: Corner shouldn't turn angle too much (may cause flipping)
world.rCornerFilter = 0.03;
world.aCornerFilter = 0.03;

world.aLineFilter = 0.04;

world.rLineFilterTop = 0.0001;
world.aLineFilterTop = 0.03;
world.rLineFilterBtm = 0.0001;
world.aLineFilterBtm = 0.02;

--New two-goalpost localization
world.use_new_goalposts=1;
--For NAO
world.use_same_colored_goal = 1;

-- Occupancy Map parameters
occ = {};
occ.mapsize = 50;
occ.robot_pos = {occ.mapsize / 2, occ.mapsize * 4 / 5};



--Use line information to fix angle
world.use_line_angles = 1;
