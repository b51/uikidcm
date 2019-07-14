cmake_minimum_required(VERSION 3.5)
project(V4LCam)

add_definitions(-std=c++11)

#########################################################################
set(CMAKE_BUILD_TYPE "Release")
if (NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE "Release")
  message(STATUS "No build type selected, default to ${CMAKE_BUILD_TYPE}")
endif()
#########################################################################

set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -O2")

add_library(V4LCam SHARED
  luaV4LCam.cc
  camera.cc
  timeScalar.cc
)

set_target_properties(${PROJECT_NAME} PROPERTIES PREFIX "")

target_link_libraries(${PROJECT_NAME}
  glog
  v4l2
)

install(TARGETS ${PROJECT_NAME}
  LIBRARY DESTINATION ${CMAKE_INSTALL_PREFIX}
)
