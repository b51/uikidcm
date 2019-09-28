## Install
### Download Source Code
```bash
$ cd ~
$ git clone https://github.com/b51/uikidcm.git
```
### Install lua 5.1.4
```bash
$ sudo apt install libreadline-dev libncurses5-dev -y
$ cd uikidcm/Tools
$ tar zxvf lua-5.1.4.tar.gz
$ cd lua-5.1.4
$ make linux
$ sudo make install
```

### Build darknet
```bash
$ cd ~
$ git clone https://github.com/pjreddie/darknet
$ cd darknet

Open Makefile with txt editor(vim or gedit), and modify it:
  GPU=0    --> GPU=1
  CUDNN=0  --> CUDNN=1
  OPENCV=0 --> OPENCV=1
  OPENMP=0 --> OPENMP=1
Than save and exit

$ make -j4

Copy to destination folder

$ cp libdarknet.so ~/uikidcm/Lib/Modules/DLDetection/lib/
```

### Build uikidcm
```bash
$ sudo apt install libboost-dev libturbojpeg0-dev -y
$ cd ~/uikidcm/Lib
$ make setup_op
$ ./dl_setup.sh
```

### Download yolo models
```bash
$ cd ~
$ git clone https://github.com/b51/YoloModels
$ cp YoloModels/humanoid_fb_yolo3_tiny_5.6/* ~/uikidcm/Player/Data/
```

### Run
```bash
$ cd ~/uikidcm/Player
$ lua run_dldcm.lua
$ lua run_dlcognition.lua
$ lua run_main_op.lua
```

This project is a modularized software framework for use with humanoid robot
development and research. The modularized platform separates low level
components that vary from robot to robot from the high level logic that does not
vary across robots. The low level components include processes to communicate
with motors and sensors on the robot, including the camera. The high level
components include the state machines that control how the humanoids move around
and process sensor data. By separating into these levels, we achieve a more
adaptable system that is easily ported to different humanoids.

The project began with the University of Pennsylvania RoboCup code base from
the 2011 RoboCup season and is continuing to evolve into an ever more
generalized and versatile robot software framework.

Copyright:
  All code sources associated with this project are freely available under the
  GPLv3 license.
