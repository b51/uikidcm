module(..., package.seeall);
require('vector')

--Localization parameters 

world={};
world.n = 250;  --tse
world.xLineBoundary = 4.5;
world.yLineBoundary = 3.0;
world.xMax = 4.5;
world.yMax = 3.0;
world.goalWidth = 1.80;
world.goalHeight= 1.10;
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
world.circle = {};
world.circle[1] = {0,0};
world.circle[2] = {0,0};

--SJ: Now kidsize is using SPL field 
--These are SPL 2013 values
world.Lcorner={};
--Field edge
world.Lcorner[1]={4.5,3,-0.75*math.pi};
world.Lcorner[2]={4.5,-3,0.75*math.pi};
world.Lcorner[3]={-4.5,3,-0.25*math.pi};
world.Lcorner[4]={-4.5,-3,0.25*math.pi};
--Penalty box edge
world.Lcorner[5]={-3.9,1.1,-0.75*math.pi};
world.Lcorner[6]={-3.9,-1.1,0.75*math.pi};
world.Lcorner[7]={3.9,1.1,-0.25*math.pi};
world.Lcorner[8]={3.9,-1.1,0.25*math.pi};
--Penalty box T edge
world.Lcorner[9]={4.5,1.1,-0.75*math.pi};
world.Lcorner[10]={4.5,-1.1,0.75*math.pi};
world.Lcorner[11]={-4.5,1.1,-0.25*math.pi};
world.Lcorner[12]={-4.5,-1.1,0.25*math.pi};
world.Lcorner[13]={4.5,1.1,0.75*math.pi};
world.Lcorner[14]={4.5,-1.1,-0.75*math.pi};
world.Lcorner[15]={-4.5,1.1,0.25*math.pi};
world.Lcorner[16]={-4.5,-1.1,-0.25*math.pi};
--Center T edge
world.Lcorner[17]={0,3,-0.25*math.pi};
world.Lcorner[18]={0,3,-0.75*math.pi};
world.Lcorner[19]={0,-3,0.25*math.pi};
world.Lcorner[20]={0,-3,0.75*math.pi};
--Center Circle Junction
world.Lcorner[21]={0,0.75,-0.25*math.pi};
world.Lcorner[22]={0,0.75,0.25*math.pi};
world.Lcorner[23]={0,0.75,-0.75*math.pi};
world.Lcorner[24]={0,0.75,0.75*math.pi};
world.Lcorner[25]={0,-0.75,-0.25*math.pi};
world.Lcorner[26]={0,-0.75,0.25*math.pi};
world.Lcorner[27]={0,-0.75,-0.75*math.pi};
world.Lcorner[28]={0,-0.75,0.75*math.pi};

--constrain the goalie to only certain goals
world.Lgoalie_corner = {}
world.Lgoalie_corner[1] = world.Lcorner[5];
world.Lgoalie_corner[2] = world.Lcorner[6];
world.Lgoalie_corner[3] = world.Lcorner[11];
world.Lgoalie_corner[4] = world.Lcorner[12];
world.Lgoalie_corner[5] = world.Lcorner[15];
world.Lgoalie_corner[6] = world.Lcorner[16];

--T corners
world.Tcorner = {};
--Penalty box T corners
world.Tcorner[1]={4.5,1.1,math.pi};
world.Tcorner[2]={4.5,-1.1,math.pi};
world.Tcorner[3]={-4.5,1.1,0};
world.Tcorner[4]={-4.5,-1.1,0};
--cirlce T corners
world.Tcorner[5]={0,3,-0.5*math.pi};
world.Tcorner[6]={0,-3,0.5*math.pi};

--T corners for goalie
world.Tgoalie_corner = {};
--Penalty box T corners
world.Tgoalie_corner[1]=world.Tcorner[3];
world.Tgoalie_corner[2]=world.Tcorner[4];

--Sigma values for one landmark observation
world.rSigmaSingle1 = .15;
world.rSigmaSingle2 = .10;
world.aSigmaSingle = 10*math.pi/180;

--Sigma values for goal observation
world.rSigmaDouble1 = .25;
world.rSigmaDouble2 = .20;
world.aSigmaDouble = 20*math.pi/180;

--[[
--SJ: NSL penalty box is very wide 
--And sometimes they can be falsely detected as T edges
--Penalty box T edge #2 
world.Lcorner[17]={2.4,2};
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
--New two-goalpost localization
world.use_new_goalposts=1;
--For NAO
world.use_same_colored_goal = 1;



--Player filter weights
if Config.game.playerID > 1 then
	--Two post observation
	world.rGoalFilter = 0;
	world.aGoalFilter = 0;

	--Single post observation
	world.rPostFilter = 0;
	world.aPostFilter = 0;

	--Single known post observation
	world.rPostFilter2 = 0;
	world.aPostFilter2 = 0;

	--Spot
	world.rSpotFilter = 0.01;
	world.aSpotFilter = 0.0001;

	--L Corner observation
	world.rLCornerFilter = 0.02
	world.aLCornerFilter = 0.01
	
	--T Corner observation
	world.rTCornerFilter = 0.03;
	world.aTCornerFilter = 0.01;
	
	--Top line observation
    world.rLineFilterTop = 0.0001
    world.aLineFilterTop = 0.005;
    
    --Bottom Line observation
    world.rLineFilterBtm = 0.01;
    world.aLineFilterBtm = 0.01;

	--Circle observation
	world.rCircleFilter = 0.02;
	world.aCircleFilter = 0.01;

else --for goalie
	--goal observation
	world.rGoalFilter = 0;
	world.aGoalFilter = 0;
	 
	 --Single post observation
	 world.rPostFilter = 0;
	 world.aPostFilter = 0;
	 
	 --Single known post observation
	 world.rPostFilter2 = 0;
	 world.aPostFilter2 = 0;
	 
	 --Spot
	 world.rSpotFilter = 0.01;
	 world.aSpotFilter = 0.001; 
	 
	 --L Corner observation
	 world.rLCornerFilter = 0.01;
	 world.aLCornerFilter = 0.01;
	
	 --T Corner observation
	 world.rTCornerFilter = 0.01;
	 world.aTCornerFilter = 0.01;
	 
	--Top line observation
    world.rLineFilterTop = 0.0001;
    world.aLineFilterTop = 0.005;
    
    --Bottom Line observation
    world.rLineFilterBtm = 0.0001;
    world.aLineFilterBtm = 0.01;
	 
	 --Circle observation
	world.rCircleFilter = 0;
	world.aCircleFilter = 0;
end

world.rLandmarkFilter = 0.05;
world.aLandmarkFilter = 0.10;

--SJ: Corner shouldn't turn angle too much (may cause flipping)
world.rCornerFilter = 0.03;
world.aCornerFilter = 0.03;

world.aLineFilter = 0.04;

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



-- Occupancy Map parameters
occ = {};
occ.mapsize = 50;
occ.robot_pos = {occ.mapsize / 2, occ.mapsize * 4 / 5};

--How much noise to add to model while walking
--More means the particles will diverge quicker
world.daNoise = 0.5*math.pi/180;
world.drNoise = 0.02;

--Use line information to fix angle
world.use_line_angles = 1;

--Various thresholds
world.angle_update_threshold = 3.0
world.angle_update_threshold_goalie = math.huge
world.triangulation_threshold = 4.0;
world.position_update_threshold = 6.0;
world.triangulation_threshold_goalie = 0;
world.position_update_threshold_goalie =0;

