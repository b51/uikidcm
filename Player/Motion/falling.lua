local Config = require('Config');
local Body = require('Body');
local walk = require('walk');

local falling_timeout = Config.falling_timeout or 5.0
local reset_timeout = Config.reset_timeout or 1.0
local t0 = Body.get_time();
local fState = '';

function entry()
  print("Motion: falling entry");

  --disable falling check when robot is falling down
  mcm.set_motion_fall_check(0);

  -- relax all the joints while falling
  Body.set_body_hardness(0);

  -- starting point of the whole safe falling process
  t0 = Body.get_time();

  Body.set_syncread_enable(1); --OP specific
  walk.stance_reset();--reset current stance

  Body.set_para_velocity(vector.new({0,0,0}));
  Body.set_state_gaitValid(1);
  Body.set_state_torqueEnable(0);

  --unix.sleep(1.0);    --tse
  fState = 'start'
  print('start falling state machine', t0);
end

function update()
  -- update function is a state machine driven by time t and t0
  local t = Body.get_time();

  if(fState == 'start') then
    if(t-t0 > falling_timeout) then
      print('translate to torque on state', t);
      Body.set_state_torqueEnable(1);
      fState = 'torqueOn'
    end
  elseif(fState == 'torqueOn') then
    if(t-t0 >reset_timeout+falling_timeout) then
      print('translate to gaitReset state', t);
      Body.set_state_gaitReset(1);
      fState = 'gaitReset'
    end
  elseif(fState == 'gaitReset') then
    if(t-t0 > 4*reset_timeout + falling_timeout) then
      local gaitReset = Body.get_state_gaitReset();
      local isComplete = Body.get_state_gaitResetPending();
      if(gaitReset[1] == 0 and isComplete[1] == 0) then
        print('gait reset is completed', t)
        fState = 'start'
        return 'done'
      end
    end
  end
end


function exit()
  local qSensor = Body.get_sensor_position();
  Body.set_actuator_command(qSensor);
end

return {
  _NAME = "falling",
  entry = entry,
  update = update,
  exit = exit,
};
