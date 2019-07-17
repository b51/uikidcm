cmake_minimum_required(VERSION 3.2)
project(OPKinematics)

add_definitions(-std=c++11)

set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -O2")

add_library(${PROJECT_NAME} SHARED
  luaOPKinematics.cc
  OPKinematics.cc
  Transform.cc
)

set_target_properties(${PROJECT_NAME} PROPERTIES PREFIX "")

install(TARGETS ${PROJECT_NAME}
  PERMISSIONS
    OWNER_EXECUTE OWNER_WRITE OWNER_READ
    GROUP_READ GROUP_WRITE GROUP_EXECUTE
    WORLD_READ WORLD_EXECUTE
  LIBRARY DESTINATION ${CMAKE_INSTALL_PREFIX}
)
