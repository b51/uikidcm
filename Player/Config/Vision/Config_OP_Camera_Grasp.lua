module(..., package.seeall);
require('vector')
require('Config')
--require('vcm')

-- Camera Parameters
use_arbitrary_ball = Config.vision.use_arbitrary_ball or false;

camera = {};
camera.ncamera = 1;
camera.switchFreq = 0; --unused for OP

camera.width = 1280;
camera.height = 720;
camera.x_center = 618.4566;
camera.y_center = 355.9215;

camera.focal_length = 982.4735; -- in pixels
camera.focal_base = 980.6277; -- image width used in focal length calculation

--[[ Tsinghua new camera intrinsics
749.976216 0.000000 666.504700
0.000000 752.193184 357.094205
0.000000 0.000000 1.000000
--]]

camera.auto_param = {};
camera.auto_param[1] = {key='white balance temperature, auto', val={1}};
camera.auto_param[2] = {key='power line frequency',   val={1}};
camera.auto_param[3] = {key='backlight compensation', val={1}};
camera.auto_param[4] = {key='exposure, auto',val={2}};
camera.auto_param[5] = {key="exposure, auto priority",val={1}};

camera.param = {};
camera.param[1] = {key='brightness',    val={0}};
camera.param[2] = {key='contrast',      val={32}};
camera.param[3] = {key='saturation',    val={60}};
camera.param[4] = {key='hue',           val={0}};
camera.param[5] = {key='gamma',         val={100}};
camera.param[6] = {key='gain',          val={0}};
camera.param[7] = {key='white balance temperature', val={4600}};
camera.param[8] = {key='sharpness',     val={3}};
camera.param[9] = {key='exposure (absolute)',      val={500}};
if use_arbitrary_ball then
  camera.lut_file = 'gateline0318.raw';
  camera.lut_ball_file = 'FieldandBall0318.raw';
else
  camera.lut_file = 'goal_test.raw';
end

