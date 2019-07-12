cmake_minimum_required(VERSION 3.2)
project(Kinematics)

add_definitions(-std=c++11)

set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -O2")

add_library(Kinematics SHARED
  luaKinematics.cc
  Kinematics.cc
  Transform.cc
)

# set library prefix to "" otherwise it will create libunix.so
set_target_properties(Kinematics PROPERTIES PREFIX "")
