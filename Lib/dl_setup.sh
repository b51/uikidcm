#########################################################################
#
#              Author: b51
#                Mail: b51live@gmail.com
#            FileName: dl_setup.sh
#
#          Created On: Sat 28 Sep 2019 11:41:09 AM CST
#
#########################################################################

#!/bin/bash

TOP=`pwd`/../

# Build ImagePreProc
cd $TOP/Lib/Modules/ImagePreProc
if [ ! -d "build" ]; then
  mkdir build
fi
cd build && cmake .. && make -j4
cp libImagePreProc.so $TOP/Player/Lib/ImagePreProc.so

# Build DLDetection
cd $TOP/Lib/Modules/DLDetection
if [ ! -d "build" ]; then
  mkdir build
fi
cd build && cmake .. && make -j4
cp libDLDetection.so $TOP/Player/Lib/DLDetection.so

# Build OPCam
cd $TOP/Lib/Platform/OP/Camera
if [ ! -d "build" ]; then
  mkdir build
fi
cd build && cmake .. && make -j4
cp libOPCam.so $TOP/Player/Lib/OPCam.so
