cmake_minimum_required(VERSION 3.2)
project(LuaUnix)

add_definitions(-std=c++11)

set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -O2")

# unix main library definition
add_library(unix SHARED
  luaunix.cc
)

# getch main library definition
add_library(getch SHARED
  luagetch.cc
)

# stty main library definition
add_library(stty SHARED
  luastty.cc
)

# set library prefix to "" otherwise it will create libunix.so
set_target_properties(unix PROPERTIES PREFIX "")
set_target_properties(getch PROPERTIES PREFIX "")
set_target_properties(stty PROPERTIES PREFIX "")
