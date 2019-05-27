cmake_minimum_required(VERSION 3.5)
project(DLImageProc
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
find_package(OpenCV REQUIRED)
find_package(CUDA REQUIRED)

#include_directories(
#)

###########
## Build ##
###########

cuda_add_library(DLImageProc SHARED
  luaDLImageProc.cc
  yuv2rgb.cu
)

target_link_libraries(DLImageProc
  ${OpenCV_LIBS}
  ${CUDA_LIBS}
  -Wl,--no-whole-archive
  -llua
)
