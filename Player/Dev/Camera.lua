require('Config');

Camera = require(Config.dev.camera);

Camera.init(Config.camera.width, Config.camera.height);
