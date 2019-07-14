cmake_minimum_required(VERSION 3.2)
project(CArray)

add_definitions(-std=c++11)

# set optimization level
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -O2")

string(TOLOWER ${PROJECT_NAME} LIBRARY_NAME)

# carray main library definition
add_library(${LIBRARY_NAME} SHARED
  luacarray.cc
)

# set library prefix to "" otherwise it will create libcarray.so
set_target_properties(${LIBRARY_NAME} PROPERTIES PREFIX "")

install(TARGETS ${LIBRARY_NAME}
  DESTINATION ${CMAKE_INSTALL_PREFIX}
)
