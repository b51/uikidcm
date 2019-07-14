cmake_minimum_required(VERSION 3.2)
project(Comm)

add_definitions(-std=c++11)

# set optimization level
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -O2")

# Comm main library definition
add_library(${PROJECT_NAME} SHARED
  luaComm.cc
)

# set library prefix to "" otherwise it will create libComm.so
set_target_properties(${PROJECT_NAME} PROPERTIES PREFIX "")

target_link_libraries(${PROJECT_NAME} m)

install(TARGETS ${PROJECT_NAME}
  LIBRARY DESTINATION ${CMAKE_INSTALL_PREFIX}
)
