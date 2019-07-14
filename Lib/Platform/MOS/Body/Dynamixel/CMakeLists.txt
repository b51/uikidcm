cmake_minimum_required(VERSION 3.2)
project(DynamixelPacket)

add_definitions(-std=c++11)

# set optimization level
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -O2")

# Comm main library definition
add_library(${PROJECT_NAME} SHARED
  luadynamixelpacket.cc
  dynamixel.cc
)

set_target_properties(${PROJECT_NAME} PROPERTIES PREFIX "")

install(TARGETS ${PROJECT_NAME}
  LIBRARY DESTINATION ${CMAKE_INSTALL_PREFIX}
)
