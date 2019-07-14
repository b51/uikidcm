cmake_minimum_required(VERSION 3.5)
project(ImagePreProc)

add_definitions(-std=c++11)

#########################################################################
set(CMAKE_BUILD_TYPE "Release")
if (NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE "Release")
  message(STATUS "No build type selected, default to ${CMAKE_BUILD_TYPE}")
endif()
#########################################################################

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

add_library(${PROJECT_NAME} SHARED
  luaImagePreProc.cc
  TurboDecode.cc
)

set_target_properties(${PROJECT_NAME} PROPERTIES PREFIX "")

target_link_libraries(${PROJECT_NAME}
  ${OpenCV_LIBS}
  lua
  glog
  v4l2
  #${LIB_TURBOJPEG}
  turbojpeg
  -Wl,--no-whole-archive
)

install(TARGETS ${PROJECT_NAME}
  LIBRARY DESTINATION ${CMAKE_INSTALL_PREFIX}
)
