--Darwin OP Commmanager for NSL 2011
module(..., package.seeall);

--Added for Hardware config file
local cwd = unix.getcwd();
package.path = cwd.."/../Config/?.lua;"..package.path;
require('DspPacket');
require('unix');
require('shm');
require('carray');
require('vector');
require('Config');
require('Transform')

dirReverse = Config.servo.dirReverse;
posZero=Config.servo.posZero;
gyrZero=Config.gyro.zero;
legBias=Config.walk.servoBias;
armBias=Config.servo.armBias;
idMap = Config.servo.idMap;
nJoint = #idMap;
scale={};
sensortmp={};



-- Setup shared memory
function shm_init()
  shm.destroy('dcmSensor');
  sensorShm = shm.new('dcmSensor');
  sensorShm.time = vector.zeros(1);
  sensorShm.count = vector.zeros(1);
  sensorShm.position = vector.zeros(nJoint);
  sensorShm.servoposition = vector.zeros(nJoint);
  sensorShm.button = vector.zeros(2); --OP has TWO buttons

  sensorShm.imuAngle = vector.zeros(3);
  sensorShm.imuAcc = vector.zeros(3);
  sensorShm.imuGyr = vector.zeros(3);
  sensorShm.imuAccRaw = vector.zeros(3);
  sensorShm.imuGyrRaw = vector.zeros(3);
  sensorShm.imuGyrBias=vector.zeros(3); --rate gyro bias
  sensorShm.temperature=vector.zeros(nJoint);
  sensorShm.battery=vector.zeros(1); --Now only use cm730 value
  sensorShm.updatedCount =vector.zeros(1);   --Increases at every cycle
  --sensorShm.odometry0 = vector.zeros(3);--123456当前路程计值
  sensorShm.odometry = vector.zeros(3); --123456当前路程计对上一次更新值的相对位移
  sensorShm.velocity = vector.zeros(3);--123456实际速度
  sensorShm.headpos = vector.zeros(2);--123456头部实际转交
  sensorShm.bodypos = vector.zeros(7);----123456



  sensortmp.odometry=vector.zeros(3);
  sensortmp.velocity=vector.zeros(3);
  sensortmp.headpos=vector.zeros(2);
  sensortmp.bodypos=vector.zeros(7);
  sensortmp.imuAngle = vector.zeros(3);

  shm.destroy('dcmActuator');
  actuatorShm = shm.new('dcmActuator');
  print(nJoint)
  actuatorShm.command = vector.zeros(nJoint);
  actuatorShm.velocity = vector.zeros(nJoint);
  actuatorShm.hardness = vector.zeros(nJoint);
  actuatorShm.offset = vector.zeros(nJoint); --in rads
  actuatorShm.bias = vector.zeros(nJoint); --in clicks
  actuatorShm.led = vector.zeros(1);

  actuatorShm.torqueEnable = vector.zeros(1); --Global torque on.off
  -- Gain 0: normal gain 1: Kick gain (more stiff)
  actuatorShm.gain=vector.zeros(nJoint);
  actuatorShm.gainChanged=vector.ones(1);  --set compliance once
  actuatorShm.velocityChanged=vector.zeros(1);
  actuatorShm.hardnessChanged=vector.zeros(1);
  actuatorShm.torqueEnableChanged=vector.zeros(1);

  actuatorShm.backled = vector.zeros(3);  --red blue green
  actuatorShm.eyeled = vector.zeros(3);   --RGB15 eye led
  actuatorShm.headled = vector.zeros(3);  --RGB15 head led
  actuatorShm.headledChanged = vector.zeros(1);

  --Dummy variable (for compatibility with nao)
  actuatorShm.ledFaceRight=vector.zeros(24);
  actuatorShm.ledFaceLeft=vector.zeros(24);
  actuatorShm.ledChest=vector.zeros(24);

  --New PID parameters variables
  --Default value is (32,0,0)
  actuatorShm.p_param=vector.ones(nJoint)*32;
  actuatorShm.i_param=vector.ones(nJoint)*0;
  actuatorShm.d_param=vector.ones(nJoint)*0;

  --SJ: list of servo IDs to read
  --0: Head only 1: All servos 2: Head+Leg
  --readID: 1 for readable, 0 for non-readable
  actuatorShm.readType=vector.zeros(1);
  actuatorShm.readID=vector.zeros(nJoint);

  --SJ: battery testing mode (read voltage from all joints)
  actuatorShm.battTest=vector.zeros(1);

  --123456flag
  shm.destroy('dcmState');
  stateShm = shm.new('dcmState');
  stateShm.gaitValid = vector.zeros(1);
  --stateShm.velComplete = vector.zeros(1);--速度设置完毕
  stateShm.specialValid = vector.zeros(1);--kick 1,standup from front 2,standup from back 3,kickForwardLeft 4;kickForwardRight 5,kickSideRight 6,kickSideLeft 7,
  stateShm.gaitReset = vector.zeros(1);
  stateShm.odometerReset = vector.zeros(1);
  stateShm.headValid = vector.zeros(1);
  stateShm.torqueEnable = vector.zeros(1);
  stateShm.sensorEnable = vector.zeros(1);
  stateShm.walkkick = vector.zeros(2);--标志量，左脚，右脚

  stateShm.specialGaitPending=vector.zeros(1);
  stateShm.gaitResetPending=vector.zeros(1);
  stateShm.resetOdometerPending=vector.zeros(1);
  stateShm.walkkickPending=vector.zeros(1);
  --123456parameters
  shm.destroy('dcmParameter');
  paraShm = shm.new('dcmParameter');
  paraShm.velocity = vector.zeros(3);--速度，与走踢角度
  paraShm.headpos = vector.zeros(2);
  paraShm.gaitID = vector.zeros(2);

  shm.destroy('dcmParameterTemp');
  paratmpShm=shm.new('dcmParameterTemp');
  paratmpShm.velocity = vector.zeros(3);
  paratmpShm.headpos = vector.zeros(2);
  paratmpShm.gaitID = vector.zeros(2);

end



-- Setup CArray mappings into shared memory
function carray_init()
  sensor = {};
  for k,v in sensorShm.next, sensorShm do
    sensor[k] = carray.cast(sensorShm:pointer(k));
  end

  actuator = {};
  for k,v in actuatorShm.next, actuatorShm do
    actuator[k] = carray.cast(actuatorShm:pointer(k));
  end

  state = {};--123456
  for k,v in stateShm.next, stateShm do
    state[k] = carray.cast(stateShm:pointer(k));
  end

  para = {};
  for k,v in paraShm.next, paraShm do
    para[k] = carray.cast(paraShm:pointer(k));
  end--123456

  paratmp = {};
  for k,v in paraShm.next, paraShm do
    paratmp[k] = carray.cast(paratmpShm:pointer(k));
  end--123456
end
--pass data to the dsp module
--[[function test_data()
  para.velocity[1]=0.03;
  para.velocity[2]=0.03;
  para.velocity[3]=0.02;
  para.headpos[1]=0.03;
  para.headpos[2]=0.03;
end]]--

function test_data()
  para.velocity[1]=0.00;
  para.velocity[2]=0.00;
  para.velocity[3]=0.00;
  para.headpos[1]=0.00;
  para.headpos[2]=0.00;
  state.gaitValid[1]=1;
  state.torqueEnable[1]=1;
  state.sensorEnable[1]=1;
end

function pass_data()
--[[
  para.velocity[1]=para.velocity[1]*1000;
  para.velocity[2]=para.velocity[2]*1000;
  para.velocity[3]=para.velocity[3]*512;
  para.headpos[1]=para.headpos[1]*512;
  para.headpos[2]=para.headpos[2]*512;
  ]]--
  --print('cmd:',para.velocity[1],para.velocity[2],para.velocity[3]);
  DspPacket.pass_state(state);
  stateCtrl();
  paraCtrl();
  DspPacket.pass_para(paratmp);
  --DspPacket.pass_para(para);
end
function stateCtrl()

  if(state.specialValid[1]==1)
     then state.specialGaitPending[1]=1;
  end
  if(state.odometerReset[1]==1)
     then state.resetOdometerPending[1]=1;
  end
  if(state.gaitReset[1]==1)
     then state.gaitResetPending[1]=1;
  end
  if(state.walkkick[1]+state.walkkick[2]>=1)
     then state.walkkickPending[1]=1;
  end;

  state.specialValid[1] = 0;
  state.gaitReset[1] = 0;
  state.odometerReset[1] = 0;
  state.walkkick[1]=0;
  state.walkkick[2]=0;
end
function paraCtrl()
  paratmp.velocity[1]=para.velocity[1]*1000;
  paratmp.velocity[2]=para.velocity[2]*1000;
  paratmp.velocity[3]=para.velocity[3]*512;
  paratmp.headpos[2]=para.headpos[1]*512;
  paratmp.headpos[1]=para.headpos[2]*512;
  paratmp.gaitID[1]=para.gaitID[1];
  paratmp.gaitID[2]=para.gaitID[2];
end
function receive_data()
  state.specialGaitPending[1],state.gaitResetPending[1],state.resetOdometerPending[1],state.walkkickPending[1]=DspPacket.get_pendingstate();

  --print(DspPacket.get_velocity());
  sensortmp.velocity[1],sensortmp.velocity[2],sensortmp.velocity[3]=DspPacket.get_velocity();
  --print(DspPacket.get_headpos());
  sensortmp.headpos[1],sensortmp.headpos[2] = DspPacket.get_headpos();
  --print(DspPacket.get_odometry());
  sensortmp.odometry[1],sensortmp.odometry[2],sensortmp.odometry[3] = DspPacket.get_odometry();
  --print(DspPacket.get_bodypos());
  sensortmp.bodypos[1],sensortmp.bodypos[2],sensortmp.bodypos[3],sensortmp.bodypos[4],sensortmp.bodypos[5],sensortmp.bodypos[6],sensortmp.bodypos[7]=DspPacket.get_bodypos();
  --print(DspPacket.get_imuAngle());
  sensortmp.imuAngle[1], sensortmp.imuAngle[2], sensortmp.imuAngle[3] = DspPacket.get_imuAngle();

  sensortrans();
end
function sensortrans()
  sensor.velocity[1]=sensortmp.velocity[1]/1000;
  sensor.velocity[2]=sensortmp.velocity[2]/1000;
  sensor.velocity[3]=sensortmp.velocity[3]/512;
  sensor.odometry[1]=sensortmp.odometry[1]/1000;
  sensor.odometry[2]=sensortmp.odometry[2]/1000;
  sensor.odometry[3]=sensortmp.odometry[3]/512;
  sensor.headpos[1]=sensortmp.headpos[1]/512;
  sensor.headpos[2]=sensortmp.headpos[2]/512;
  sensor.bodypos[1]=sensortmp.bodypos[1];
  sensor.bodypos[2]=sensortmp.bodypos[2]/1000;
  sensor.bodypos[3]=sensortmp.bodypos[3]/1000;
  sensor.bodypos[4]=sensortmp.bodypos[4]/1000;
  sensor.bodypos[5]=sensortmp.bodypos[5]/512;
  sensor.bodypos[6]=sensortmp.bodypos[6]/512;
  sensor.bodypos[7]=sensortmp.bodypos[7]/512;
  sensor.imuAngle[1] = sensortmp.imuAngle[1]/512;
  sensor.imuAngle[2] = sensortmp.imuAngle[2]/512;
  sensor.imuAngle[3] = sensortmp.imuAngle[3]/512;
end

function entry()
--  print("Initializ-------------------------------------------------");
  unix.usleep(200000);
  shm_init();
  carray_init();
  test_data();
  --pass_data();
  --print(type(state));
  --table.foreach(state,function(i,v) print (i,DspPacket.get_carray_n(state[i],1) ) end)
  --table.foreach(para,function(i,v) print(i,v) end)
  DspPacket.enter_entry();
--  print("Finish_initializ------------------------------------------")
end


function update()
-- test_data();
-- print("pass_data_to_dsp-------------------------------------------");
 pass_data();
-- print("dsp_thread-------------------------------------------------");
 DspPacket.dsp_thread();
-- print("receive_data_from_dsp--------------------------------------");
 receive_data();
-- print("finish_receive---------------------------------------------");
-- unix.usleep(300000);
end

function exit()
 DspPacket.dsp_exit();
end
