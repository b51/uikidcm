cmake_minimum_required(VERSION 3.5)
project(ImagePreProc
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

#set(LIB_TURBOJPEG /usr/lib/aarch64-linux-gnu/libturbojpeg.so.0)
## Find catkin macros and libraries
find_package(OpenCV REQUIRED)

include_directories(
  ${OpenCV_INCLUDE_DIRS}
)

###########
## Build ##
###########

add_library(ImagePreProc SHARED
  luaImagePreProc.cc
  TurboDecode.cc
)

target_link_libraries(ImagePreProc
  ${OpenCV_LIBS}
  lua
  glog
  v4l2
  #${LIB_TURBOJPEG}
  turbojpeg
  -Wl,--no-whole-archive
)
