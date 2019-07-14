cmake_minimum_required(VERSION 3.2)
project(CUtil)

add_definitions(-std=c++11)

# set optimization level
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -O2")

string(TOLOWER ${PROJECT_NAME} LIBRARY_NAME)

# cutil main library definition
add_library(${LIBRARY_NAME} SHARED
  luacutil.cc
)

# set library prefix to "" otherwise it will create libcutil.so
set_target_properties(${LIBRARY_NAME} PROPERTIES PREFIX "")

install(TARGETS ${LIBRARY_NAME}
  LIBRARY DESTINATION ${CMAKE_INSTALL_PREFIX}
)
