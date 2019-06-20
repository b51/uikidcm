## Instruction
Modules need compile manual: Camera, ImagePreProc, DLDetection

### Build and copy to Lib
```
Shared lib so build by cmake will auto add prefix to so files, so
we should remove lib prefix when copy to Lib directory.
eg. Camera
$ cd Platform/OP/Camera
$ cd build
$ make -j4 && cp *.so ~/Humanoid/uikidcm/Player/Lib/OPCam.so
```
