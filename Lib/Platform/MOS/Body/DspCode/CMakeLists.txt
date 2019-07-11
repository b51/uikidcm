cmake_minimum_required(VERSION 3.2)
project(DspPacket)

add_definitions(-std=c++11)

# set optimization level
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -O2")

find_package(Boost REQUIRED)
include_directories(
  ${Boost_INCLUDE_DIRS}
)

# Comm main library definition
add_library(DspPacket SHARED
  luaDspCode.cc
)

# set library prefix to "" otherwise it will create libComm.so
set_target_properties(DspPacket PROPERTIES PREFIX "")
