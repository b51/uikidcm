local Config = require('Config');

local Camera = require(Config.dev.camera);
Camera.init(Config.camera.width, Config.camera.height);

return Camera;
