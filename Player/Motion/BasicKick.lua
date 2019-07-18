local unix = require('unix')
local util = require('util')
local mcm = require('mcm')
local vector = require('vector')
local Body = require('Body')
local Config = require('Config')
local walk = require('walk')
local keyframe = require('keyframe')
-- TODO(b51): lots code useless, needs cleanup

local cwd = unix.getcwd();
cwd = cwd.."/Motion"

--Kick definition list
local kickDefList = Config.kick.def;

-- default kick type
local kickType = "kickForwardLeft";

local active = false;

local t0 = Body.get_time();
local qLArm0 = Config.kick.qLArm;
local qRArm0 = Config.kick.qRArm;
local armGain = Config.kick.armGain;

local qLArm = vector.new({qLArm0[1],qLArm0[2],qLArm0[3]});
local qRArm = vector.new({qRArm0[1],qRArm0[2],qRArm0[3]});

local bodyHeight = Config.walk.bodyHeight;
local footX = Config.walk.footX;
local footY = Config.walk.footY;
local bodyTilt = Config.walk.bodyTilt;
local supportX = Config.walk.supportX;

local bodyRoll=0;

local ankleShift = vector.new({0, 0});
local kneeShift=0;
local hipShift=vector.new({0,0});
local armShift = vector.new({0, 0});

local ankleImuParamX=Config.kick.ankleImuParamX;
local kneeImuParamX=Config.kick.kneeImuParamX;
local hipImuParamY=Config.kick.hipImuParamY;
local ankleImuParamY=Config.kick.ankleImuParamY;

local armImuParamX=Config.kick.armImuParamX;
local armImuParamY=Config.kick.armImuParamX;

local qLHipRollCompensation=0;
local qRHipRollCompensation=0;

local supportCompL=Config.walk.supportCompL;
local supportCompR=Config.walk.supportCompR;

local hardnessArm=Config.kick.hardnessArm;
local hardnessLeg=Config.kick.hardnessLeg;

local kickState=1;

local hipRollCompensation = Config.kick.hipRollCompensation or 5*math.pi/180;

local pTorso = vector.new({0, 0, bodyHeight, 0,bodyTilt,0});
local pLLeg=vector.zeros(6);
local pRLeg=vector.zeros(6);

local kickXComp = mcm.get_kickX();
local kickYComp = Config.walk.kickYComp;

local torsoShiftX=0;
local started = false;
--Parse kick definition
local kickDef = kickDefList[kickType].def;
local supportLeg = kickDefList[kickType].supportLeg;

local uLeft= vector.new({-supportX, footY, 0});
local uRight=vector.new({-supportX, -footY, 0});
local uLeft1= vector.new({-supportX, footY, 0});
local uRight1=vector.new({-supportX, -footY, 0});

local uBody=vector.new({0,0,0});
local uBody1=vector.new({0,0,0});

local zLeft,zRight = 0, 0;
local zLeft1,zRight1 = 0,0;
local aLeft,aRight=0,0;
local aLeft1,aRight1=0,0;
local zBody,zBody1=bodyHeight,bodyHeight;
local bodyRoll,bodyRoll1=0,0;
local qLHipRollCompensation,qRHipRollCompensation= 0,0;

local motion_legs = function()
--Ankle stabilization using gyro feedback
  imuGyr = Body.get_sensor_imuGyrRPY();
  gyro_roll=imuGyr[1];
  gyro_pitch=imuGyr[2];

  ankleShiftX=util.procFunc(gyro_pitch*ankleImuParamX[2],ankleImuParamX[3],ankleImuParamX[4]);
  ankleShiftY=util.procFunc(gyro_roll*ankleImuParamY[2],ankleImuParamY[3],ankleImuParamY[4]);
  kneeShiftX=util.procFunc(gyro_pitch*kneeImuParamX[2],kneeImuParamX[3],kneeImuParamX[4]);
  hipShiftY=util.procFunc(gyro_roll*hipImuParamY[2],hipImuParamY[3],hipImuParamY[4]);
  armShiftX=util.procFunc(gyro_pitch*armImuParamX[2],armImuParamX[3],armImuParamX[4]);
--  armShiftY=util.procFunc(gyro_roll*armImuParamY[2],armImuParamY[3],armImuParamY[4]);
  armShiftY = 0; --No arm Y stabilization during kick

  ankleShift[1]=ankleShift[1]+ankleImuParamX[1]*(ankleShiftX-ankleShift[1]);
  ankleShift[2]=ankleShift[2]+ankleImuParamY[1]*(ankleShiftY-ankleShift[2]);
  kneeShift=kneeShift+kneeImuParamX[1]*(kneeShiftX-kneeShift);
  hipShift[2]=hipShift[2]+hipImuParamY[1]*(hipShiftY-hipShift[2]);

  armShift[1]=armShift[1]+armImuParamX[1]*(armShiftX-armShift[1]);
  armShift[2]=armShift[2]+armImuParamY[1]*(armShiftY-armShift[2]);

  qLegs = Kinematics.inverse_legs(pLLeg, pRLeg, pTorso,0);

  if kicktype==4 then	--Left kick
    qLegs[10] = qLegs[10] + kneeShift;
    qLegs[11] = qLegs[11]  + ankleShift[1];
  elseif kicktype==5 then  --Right kick
    qLegs[4] = qLegs[4] + kneeShift;
    qLegs[5] = qLegs[5]  + ankleShift[1];
  else
    qLegs[4] = qLegs[4] + kneeShift;
    qLegs[5] = qLegs[5]  + ankleShift[1];
    qLegs[10] = qLegs[10] + kneeShift;
    qLegs[11] = qLegs[11]  + ankleShift[1];
  end

  qLegs[2] = qLegs[2] + qLHipRollCompensation+hipShift[2];
  qLegs[8] = qLegs[8] + qRHipRollCompensation+hipShift[2];

  qLegs[6] = qLegs[6] + ankleShift[2];
  qLegs[12] = qLegs[12] + ankleShift[2];
  Body.set_lleg_command(qLegs);
end

local motion_arms = function()
  qLArm[1],qLArm[2]=qLArm0[1]+armShift[1],qLArm0[2]+armShift[2];
  qRArm[1],qRArm[2]=qRArm0[1]+armShift[1],qRArm0[2]+armShift[2];

  local uBodyLeft=util.pose_relative(uLeft,uBody);
  local uBodyRight=util.pose_relative(uRight,uBody);
  local footRel=uBodyLeft[1]-uBodyRight[1];

  local armAngle=math.min(50*math.pi/180,
                    math.max(-50*math.pi/180,
                        footRel/armGain * 50*math.pi/180));
  qLArm[1]=qLArm[1]+armAngle;
  qRArm[1]=qRArm[1]-armAngle;
  Body.set_larm_command(qLArm);
  Body.set_rarm_command(qRArm);
end

local entry = function()
  print("Motion: kick entry");
  kickXComp = mcm.get_kickX();
  footX = mcm.get_footX();
  walk.stop();
  qLArm = vector.new({qLArm0[1],qLArm0[2],qLArm0[3]});
  qRArm = vector.new({qRArm0[1],qRArm0[2],qRArm0[3]});
  torsoShiftX=0;
  started = false;
  active = true;

  -- disable joint encoder reading
  Body.set_syncread_enable(0);

  t0 = Body.get_time();
end

local update = function()
  if (not started and walk.active) then
    walk.update();
    return;
  elseif not started then
    started=true;
    Body.set_head_hardness(.5);
    Body.set_larm_hardness(hardnessArm);
    Body.set_rarm_hardness(hardnessArm);
    Body.set_lleg_hardness(hardnessLeg);
    Body.set_rleg_hardness(hardnessLeg);
    kickState=1;
    print('kick start');
    Body.set_state_specialValid(1);   ----------123456kick 开始
    ----------------tse------------------
    --unix.sleep(7.0);   -- for Technical Challenge Throw-in (pick-up specialGait and throw-in specialGait)
    -- add throw-in gaitID
    ----------------tse------------------
  end

  local t=Body.get_time();
  local ph=(t-t0)/kickDef[kickState][2];
  if ph>1 then
    print("ph, t-t0, kickStatetime :",ph, t-t0, kickDef[kickState][2]);
    kickState=kickState+1;
    uLeft1[1],uLeft1[2],uLeft1[3]=uLeft[1],uLeft[2],uLeft[3];
    uRight1[1],uRight1[2],uRight1[3]=uRight[1],uRight[2],uRight[3];
    uBody1[1],uBody1[2],uBody1[3]=uBody[1],uBody[2],uBody[3];
    zLeft1,zRight1=zLeft,zRight;
    aLeft1,aRight1=aLeft,aRight;
    bodyRoll1=bodyRoll;
    zBody1=zBody;
    local specialValid = Body.get_state_specialValid();   -------123456kick 结束
    local isComplete = Body.get_state_specialGaitPending();
    if kickState>#kickDef then
      print("#kickDef, kickState :",#kickDef, kickState);
      if (specialValid[1] == 0 and isComplete[1] == 0) then
        print('stop later');
        return "done";  ----------------123456kick 後于结束
      else
        return;
      end
    -- elseif (specialValid[1] == 0 and isComplete[1] == 0) then ---------123456kick 先于结束
    -- print('stop ealiear');
    -- return "done";   -----------123456kick 先于结束
    end
    ph=0;
    t0=t;
    if supportLeg ==0 then --left support
      Body.set_lleg_slope(1);
      Body.set_rleg_slope(0);
    else --right support
      Body.set_rleg_slope(1);
      Body.set_lleg_slope(0);
    end
  end
  local kickStepType=kickDef[kickState][1];

  -- Tosro X position offxet (for differetly calibrated robots)
  if kickState==2 then --Initial slide
     torsoShiftX=kickXComp*ph;
  elseif kickState == #kickDef-1 then
     torsoShiftX=kickXComp*(1-ph);
  end

  if kickState==3 then --Lift step
    if kickStepType==2 then --
      qRHipRollCompensation= -hipRollCompensation*ph;
    elseif kickStepType==3 then
      qLHipRollCompensation= hipRollCompensation*ph;
    end
  elseif kickState == #kickDef then --Final step
    if qRHipRollCompensation<0 then
      qRHipRollCompensation= -hipRollCompensation*(1-ph);
    elseif qLHipRollCompensation>0 then
      qLHipRollCompensation= hipRollCompensation*(1-ph);
    end
  end

  if kickStepType==1 then
    uBody=util.se2_interpolate(ph,uBody1,kickDef[kickState][3]);
    if #kickDef[kickState]>=4 then
      zBody=ph*kickDef[kickState][4] + (1-ph)*zBody1;
    end
    if #kickDef[kickState]>=5 then
      bodyRoll=ph*kickDef[kickState][5] + (1-ph)*bodyRoll1;
    end

  elseif kickStepType ==6 then --Returning to walk stance
    uBody=util.se2_interpolate(ph,uBody1,kickDef[kickState][3]);
    zBody=ph*bodyHeight + (1-ph)*zBody1;
    bodyRoll=(1-ph)*bodyRoll1;
    qLArm = vector.new({qLArm0[1],qLArm0[2],qLArm0[3]});
    qRArm = vector.new({qRArm0[1],qRArm0[2],qRArm0[3]});

  elseif kickStepType==2 then --Lifting / Landing Left foot
    uLeft=util.se2_interpolate(ph,uLeft1,
    util.pose_global(kickDef[kickState][4],uLeft1));
    zLeft=ph*kickDef[kickState][5] + (1-ph)*zLeft1;
    aLeft=ph*kickDef[kickState][6] + (1-ph)*aLeft1;

  elseif kickStepType==3 then --Lifting / Landing Right foot
    uRight=util.se2_interpolate(ph,uRight1,
    util.pose_global(kickDef[kickState][4],uRight1));
    zRight=ph*kickDef[kickState][5] + (1-ph)*zRight1;
    aRight=ph*kickDef[kickState][6] + (1-ph)*aRight1;

  elseif kickStepType==4 then --Kicking Left foot
    uLeft=util.pose_global(kickDef[kickState][4],uLeft1);
    zLeft=kickDef[kickState][5]
    aLeft=kickDef[kickState][6]

  elseif kickStepType==5 then --Kicking Right foot
    uRight=util.pose_global(kickDef[kickState][4],uRight1);
    zRight=kickDef[kickState][5]
    aRight=kickDef[kickState][6]
  end

  local uLeftActual=util.pose_global(supportCompL, uLeft);
  local uRightActual=util.pose_global(supportCompR, uRight);

  pLLeg[1],pLLeg[2],pLLeg[3],pLLeg[5],pLLeg[6]=uLeftActual[1],uLeftActual[2],zLeft,aLeft,uLeftActual[3];
  pRLeg[1],pRLeg[2],pRLeg[3],pRLeg[5],pRLeg[6]=uRightActual[1],uRightActual[2],zRight,aRight,uRightActual[3];

  local uTorso=util.pose_global(vector.new({-footX-torsoShiftX,0,0}),uBody);

  pTorso[1],pTorso[2],pTorso[6]=uTorso[1],uTorso[2],uTorso[3];
  pTorso[3],pTorso[4]=zBody,bodyRoll;

  motion_legs();
  motion_arms();
end

local exit = function()
  print("Kick exit");
  active = false;

  Body.set_rleg_slope(0);
  Body.set_lleg_slope(0);

  walk.start();
--  step.stepqueue={};
end

local set_kick = function(newKick)
  if (kickDefList[newKick]) then
    kickType = newKick;
    if (kickType == "kickForwardLeft") then
      Body.set_para_gaitID(vector.new({1,1})); ---------123456kick type
    elseif (kickType == "kickForwardRight") then
      Body.set_para_gaitID(vector.new({2,1})); ---------123456kick type
    elseif (kickType == "kickSideRight") then
      Body.set_para_gaitID(vector.new({2,1}));----------123456kick type
    elseif (kickType == "kickSideLeft") then
      Body.set_para_gaitID(vector.new({1,1}));----------123456kick type
    end
  end
end

return {
  _NAME = "kick",
  entry = entry,
  update = update,
  exit = exit,
  set_kick = set_kick,
};
