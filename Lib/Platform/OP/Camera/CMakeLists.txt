cmake_minimum_required(VERSION 3.5)
project(OPCam
  VERSION 0.1.0)

add_definitions(-std=c++11)

#########################################################################
set(CMAKE_BUILD_TYPE "Release")
if (NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE "Release")
  message(STATUS "No build type selected, default to ${CMAKE_BUILD_TYPE}")
endif()
#########################################################################

set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -O2")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -O2")

## Find catkin macros and libraries
find_package(Boost REQUIRED COMPONENTS signals system thread)
find_package(OpenCV REQUIRED)
find_package(CUDA REQUIRED)

set(NV_LIBS_ROOT /usr/lib/aarch64-linux-gnu/tegra)
find_library(NvJpeg nvjpeg "${NV_LIBS_ROOT}")
find_library(NvBuf_Utils nvbuf_utils "${NV_LIBS_ROOT}")
find_library(NvOsd nvosd "${NV_LIBS_ROOT}")
set(NV_LIBS ${NvJpeg} ${NvBuf_Utils} ${NvOsd})

###################################
## catkin specific configuration ##
###################################

include_directories(
  /usr/include/drm
  ${PROJECT_SOURCE_DIR}/Nv
  ${Boost_INCLUDE_DIRS}
)


file(GLOB NvClassesSrc
  NvClasses/*.cpp
)

###########
## Build ##
###########

cuda_add_library(OPCam SHARED
  OPCam.cpp
  camera.cc
  timeScalar.cc
  #ImageDecode.cc
  #yuv2rgb.cu
  #${NvClassesSrc}
)

target_link_libraries(OPCam
  ${OpenCV_LIBS}
  ${Boost_LIBRARIES}
  ${NV_LIBS}
  ${CUDA_LIBS}
  X11
  drm
  pthread
  glog
  GLESv2
  v4l2
  -Wl,--no-whole-archive
)
