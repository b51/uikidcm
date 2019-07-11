cmake_minimum_required(VERSION 3.2)
project(Dynamixel)

add_definitions(-std=c++11)

# set optimization level
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -O2")

# Comm main library definition
add_library(DynamixelPacket SHARED
  luadynamixelpacket.cc
  dynamixel.cc
)

# set library prefix to "" otherwise it will create libComm.so
set_target_properties(DynamixelPacket PROPERTIES PREFIX "")
